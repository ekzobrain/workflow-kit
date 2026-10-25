# frozen_string_literal: true

require "bigdecimal"

module FEEL
  #
  # Semantics of FEEL values: type kinds, equality, comparison and property
  # access. Mixed into the AST nodes.
  #
  module Values
    def access_property(result, property_name)
      case result
      when ->(value) { Temporal.temporal?(value) }
        Temporal.property(result, property_name)
      when FEEL::Range
        case property_name
        when "start" then result.start
        when "end" then result.end
        when "start included" then result.start_included
        when "end included" then result.end_included
        end
      when Hash, Scope
        if result.key?(property_name.to_sym)
          result[property_name.to_sym]
        else
          result[property_name]
        end
      end
    end

    # Path access (`value.name`). Applied to a list, it returns the property of
    # each item.
    def path_get(value, property_name)
      if value.is_a?(Array)
        value.map { |item| path_get(item, property_name) }
      else
        access_property(value, property_name)
      end
    end

    # Checks whether a value is an instance of a FEEL type (`instance of`).
    def feel_instance_of?(input, type_text)
      case type_text
      when "Any" then !input.nil?
      when "Null" then input.nil?
      when "string" then input.is_a?(String)
      when "number" then Numbers.number?(input)
      when "boolean" then input == true || input == false
      when "date", "time", "date and time", "duration", "years and months duration", "days and time duration"
        Temporal.instance_of_type?(input, type_text)
      when "context" then input.is_a?(Hash) || input.is_a?(Scope)
      when "function" then input.is_a?(Function) || input.is_a?(Proc) || input.is_a?(Method)
      when "list" then input.is_a?(Array)
      when "range" then input.is_a?(FEEL::Range)
      when /[<>]/ then Types.instance_of?(input, type_text, self)
      else false
      end
    end

    # Fast paths use `Class === value` rather than `is_a?`, because
    # ActiveSupport::Duration (accepted as input) pretends to be an Integer
    # with `is_a?`.
    def type_kind(value)
      case value
      when nil then :null
      when true, false then :boolean
      when String then :string
      when Integer, Float, BigDecimal then :number
      when ->(v) { Temporal.temporal?(v) } then Temporal.kind(value)
      when Numeric then :number
      when String then :string
      when Array then :list
      when Hash, Scope then :context
      when Function, Proc, Method then :function
      else :other
      end
    end

    def feel_equal(left, right)
      return left == right if plain_value?(left) && plain_value?(right)

      if Temporal.temporal?(left) || Temporal.temporal?(right)
        Temporal.equal(left, right)
      elsif left.is_a?(Array) && right.is_a?(Array)
        left.length == right.length && left.zip(right).all? { |l, r| feel_equal(l, r) }
      elsif (left.is_a?(Hash) || left.is_a?(Scope)) && (right.is_a?(Hash) || right.is_a?(Scope))
        l = left.to_h.transform_keys(&:to_s)
        r = right.to_h.transform_keys(&:to_s)
        l.keys.sort == r.keys.sort && l.all? { |key, value| feel_equal(value, r[key]) }
      else
        left == right
      end
    end

    # Equality that returns nil (instead of false) for values of different types.
    def feel_equal_or_nil(left, right)
      return left.nil? && right.nil? if left.nil? || right.nil?
      return nil unless type_kind(left) == type_kind(right)

      feel_equal(left, right)
    end

    def feel_compare(operator, left, right)
      if (plain_number?(left) && plain_number?(right)) || (String === left && String === right)
        return compare_plain(operator, left, right)
      end
      return nil if left.nil? || right.nil?
      return nil if left == true || left == false || right == true || right == false
      return Temporal.compare(operator, left, right) if Temporal.temporal?(left) || Temporal.temporal?(right)

      left.public_send(operator, right)
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    # Strings and numbers (not durations).
    def plain_value?(value)
      String === value || Integer === value || Float === value || BigDecimal === value
    end

    def plain_number?(value)
      Integer === value || Float === value || BigDecimal === value
    end

    def compare_plain(operator, left, right)
      case operator
      when "<" then left < right
      when "<=" then left <= right
      when ">" then left > right
      when ">=" then left >= right
      else left.public_send(operator, right)
      end
    end

    # Three-valued OR of the given results: true if any is true, false if all
    # are false, otherwise null.
    def any_true(results)
      return true if results.any? { |r| r == true }
      return false if results.all? { |r| r == false }

      nil
    end

    # Matches an input value against the result of a unary test expression.
    def unary_match(input, value)
      return true if value == true
      # a list of values or ranges
      return true if value.is_a?(Array) && value.any? { |item| item.is_a?(FEEL::Range) ? item.include?(input) == true : feel_equal(item, input) }

      equal = feel_equal_or_nil(input, value)
      return true if equal == true
      return false if value == false || value.is_a?(Array)

      equal
    end
  end

  #
  # FEEL numbers. Decimal literals are parsed as BigDecimal; values coming
  # from Ruby may also be Integer or Float. Addition, subtraction and
  # multiplication are exact (not rounded to 34 digits as in DMN's decimal128,
  # on purpose: no silent rounding, like SQL DECIMAL). A quotient is rounded
  # to 34 significant digits, half to even (like decimal128). Results handed
  # back to Ruby are normalized with `Numbers.normalize`.
  #
  module Numbers
    # Significant digits of quotients (like IEEE 754 decimal128).
    DIVISION_PRECISION = 34

    module_function

    # True for FEEL numbers. `Numeric ===` (unlike `is_a?`) excludes
    # ActiveSupport::Duration, which pretends to be Numeric.
    def number?(value)
      Numeric === value
    end

    # Converts a Ruby number into an exact FEEL number (Integer or BigDecimal).
    # Returns nil for non-numbers and for NaN / infinite values.
    def decimal(value)
      case value
      when Integer then value
      when BigDecimal then value.finite? ? value : nil
      when Float then value.finite? ? BigDecimal(value.to_s) : nil
      when Rational then round(value)
      end
    end

    # The quotient of two FEEL numbers, rounded to 34 significant digits,
    # half to even: an Integer if it is integral, otherwise a BigDecimal.
    # Raises ZeroDivisionError.
    def divide(left, right)
      if Integer === left && Integer === right
        quotient, remainder = left.divmod(right)
        return quotient if remainder.zero? && quotient.abs < 10**DIVISION_PRECISION
      end

      left = decimal(left)
      right = decimal(right)
      raise ZeroDivisionError, "divided by 0" if right.zero?

      fast_divide(left, right) || round(left.to_r / right.to_r)
    end

    # Digits of the approximate quotient of fast_divide.
    APPROXIMATION_DIGITS = DIVISION_PRECISION + 6
    # Digits 35..40 of an approximate quotient close to a tie at digit 35.
    NEAR_TIES = %w[499999 500000 500001].freeze

    # The quotient computed with BigDecimal#div to 40 digits (whatever the
    # BigDecimal.mode, the error is below one unit of digit 40), then
    # rounded half to even. Nil if the quotient is too close to a tie at
    # digit 35 to decide (then it's computed exactly).
    def fast_divide(left, right)
      quotient = BigDecimal(left).div(right, APPROXIMATION_DIGITS)
      return 0 if quotient.zero?

      digits = quotient.split[1]
      return nil if NEAR_TIES.include?(digits.ljust(APPROXIMATION_DIGITS, "0")[DIVISION_PRECISION, 6])

      result = quotient.round(DIVISION_PRECISION - quotient.exponent, :half_even)
      result.frac.zero? ? result.to_i : result
    end

    # A Rational rounded to 34 significant digits, half to even, as an
    # Integer or a BigDecimal. Computed exactly (independently of
    # BigDecimal.mode).
    def round(rational)
      return rational.to_i if rational.denominator == 1 && rational.numerator.abs < 10**DIVISION_PRECISION
      return 0 if rational.zero?

      # 10**(exponent - 1) <= |rational| < 10**exponent
      numerator = rational.numerator.abs
      denominator = rational.denominator
      exponent = numerator.to_s.length - denominator.to_s.length
      exponent += 1 if exponent >= 0 ? numerator >= denominator * (10**exponent) : numerator * (10**-exponent) >= denominator
      scale = DIVISION_PRECISION - exponent
      digits = (scale >= 0 ? rational * (10**scale) : rational / (10**-scale)).round(half: :even)
      result = BigDecimal(digits) * BigDecimal("1e#{-scale}")
      result.frac.zero? ? result.to_i : result
    end

    # Converts a FEEL result for Ruby callers: BigDecimal (and Rational) become
    # an Integer when integral, a Float when the Float has exactly the same
    # value (e.g. 0.3, 1.5), otherwise a BigDecimal (e.g. the 34 digits of
    # 1 / 3), so that no precision is lost. NaN and infinite values become
    # nil. Temporal values of other Ruby types (e.g. ActiveSupport durations
    # passed in as variables) become FEEL temporal values. Arrays and Hashes
    # are normalized recursively.
    def normalize(value)
      case value
      when BigDecimal, Rational, Float
        return nil if value.respond_to?(:finite?) && !value.finite?
        return value if value.is_a?(Float)
        return value.to_i if value == value.truncate

        value = round(value) if value.is_a?(Rational)
        return value if Integer === value

        exact_float(value) || value
      when Array then value.map { |item| normalize(item) }
      when Hash then value.transform_values { |item| normalize(item) }
      else Temporal.normalize(value)
      end
    end

    # The Float of a BigDecimal if it has exactly the same value, else nil.
    def exact_float(decimal)
      float = decimal.to_f
      float if float.finite? && BigDecimal(float.to_s) == decimal
    end

    # String representation of a FEEL number, e.g. "1.5", "3" or "0.1".
    def format(value)
      value = decimal(value)
      return if value.nil?
      return value.to_s if value.is_a?(Integer)

      value == value.truncate ? value.to_i.to_s : value.to_s("F")
    end
  end

  #
  # 4. arithmetic expression
  #
  module Arithmetic
    def add(left, right)
      return left + right if (Integer === left && Integer === right) || (String === left && String === right)
      return temporal_add(left, right) if temporal_operand?(left, right)
      return numeric_operation(left, right) { |l, r| l + r } if Numbers.number?(left) && Numbers.number?(right)
      return nil if left.nil? || right.nil?
      return nil if left.is_a?(Array) || right.is_a?(Array) || left.is_a?(Hash) || right.is_a?(Hash)
      return nil if left.is_a?(String) ^ right.is_a?(String)

      left + right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def subtract(left, right)
      return left - right if Integer === left && Integer === right
      return temporal_subtract(left, right) if temporal_operand?(left, right)
      return numeric_operation(left, right) { |l, r| l - r } if Numbers.number?(left) && Numbers.number?(right)
      return nil if left.nil? || right.nil?
      return nil if left.is_a?(String) || right.is_a?(String) || left.is_a?(Array) || right.is_a?(Array)

      left - right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def multiply(left, right)
      return left * right if Integer === left && Integer === right
      return temporal_multiply(left, right) if temporal_operand?(left, right)
      return numeric_operation(left, right) { |l, r| l * r } if Numbers.number?(left) && Numbers.number?(right)
      nil
    end

    def divide(left, right)
      return temporal_divide(left, right) if temporal_operand?(left, right)
      return numeric_operation(left, right) { |l, r| decimal_divide(l, r) } if Numbers.number?(left) && Numbers.number?(right)
      nil
    end

    #
    # Temporal arithmetic (date, time, date and time, durations), see FEEL::Temporal.
    #
    def temporal_operand?(left, right)
      Temporal.temporal?(left) || Temporal.temporal?(right)
    end

    def temporal_add(left, right)
      return nil if left.nil? || right.nil?

      Temporal.add(left, right)
    rescue ArgumentError, NoMethodError, TypeError, RangeError, ZeroDivisionError
      nil
    end

    def temporal_subtract(left, right)
      return nil if left.nil? || right.nil?

      Temporal.subtract(left, right)
    rescue ArgumentError, NoMethodError, TypeError, RangeError, ZeroDivisionError
      nil
    end

    def temporal_multiply(left, right)
      return nil if left.nil? || right.nil?

      Temporal.multiply(left, right)
    rescue ArgumentError, NoMethodError, TypeError, RangeError, ZeroDivisionError
      nil
    end

    def temporal_divide(left, right)
      return nil if left.nil? || right.nil?

      Temporal.divide(left, right)
    rescue ArgumentError, NoMethodError, TypeError, RangeError, ZeroDivisionError
      nil
    end

    private

    # Applies an operation on exact numbers (Integer / BigDecimal).
    def numeric_operation(left, right)
      left = Numbers.decimal(left)
      right = Numbers.decimal(right)
      return nil if left.nil? || right.nil?

      yield(left, right)
    rescue ArgumentError, TypeError, ZeroDivisionError, FloatDomainError
      nil
    end

    def decimal_divide(left, right)
      return nil if right.zero?

      Numbers.divide(left, right)
    end
  end
end
