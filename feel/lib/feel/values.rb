# frozen_string_literal: true

module FEEL
  #
  # Semantics of FEEL values: type kinds, equality, comparison and property
  # access. Mixed into the AST nodes.
  #
  module Values
    def access_property(result, property_name)
      case result
      when DateTime
        case property_name
        when "year" then result.year
        when "month" then result.month
        when "day" then result.day
        when "weekday" then result.cwday
        when "hour" then result.hour
        when "minute" then result.min
        when "second" then result.sec
        when "time offset" then (result.offset * 1.day).to_i.seconds
        end
      when Date
        case property_name
        when "year" then result.year
        when "month" then result.month
        when "day" then result.day
        when "weekday" then result.cwday
        end
      when Time
        case property_name
        when "hour" then result.hour
        when "minute" then result.min
        when "second" then result.sec
        when "time offset" then result.utc_offset
        when "timezone" then result.zone
        end
      when ActiveSupport::Duration
        case property_name
        when "years" then result.parts[:years] || 0
        when "months" then result.parts[:months] || 0
        when "days" then result.parts[:days] || 0
        when "hours" then result.parts[:hours] || 0
        when "minutes" then result.parts[:minutes] || 0
        when "seconds" then result.parts[:seconds] || 0
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

    YEAR_MONTH_PARTS = %i[years months].freeze
    DAY_TIME_PARTS = %i[weeks days hours minutes seconds].freeze

    # Checks whether a value is an instance of a FEEL type (`instance of`).
    def feel_instance_of?(input, type_text)
      case type_text
      when "Any" then !input.nil?
      when "Null" then input.nil?
      when "string" then input.is_a?(String)
      when "number" then input.is_a?(Numeric)
      when "boolean" then input == true || input == false
      when "date" then input.is_a?(Date) && !input.is_a?(DateTime)
      when "time" then input.is_a?(Time)
      when "date and time" then input.is_a?(DateTime) || input.is_a?(ActiveSupport::TimeWithZone)
      when "duration" then input.is_a?(ActiveSupport::Duration)
      when "years and months duration" then duration_with_parts?(input, YEAR_MONTH_PARTS)
      when "days and time duration" then duration_with_parts?(input, DAY_TIME_PARTS)
      when "context" then input.is_a?(Hash) || input.is_a?(Scope)
      when "function" then input.is_a?(Function) || input.is_a?(Proc) || input.is_a?(Method)
      when /\Alist\b/ then input.is_a?(Array)
      when /\Acontext\b/ then input.is_a?(Hash) || input.is_a?(Scope)
      when /\Afunction\b/ then input.is_a?(Function) || input.is_a?(Proc) || input.is_a?(Method)
      else false
      end
    end

    def duration_with_parts?(input, parts)
      return false unless input.is_a?(ActiveSupport::Duration)
      return true if input.parts.empty?

      (input.parts.keys - parts).empty?
    end

    def type_kind(value)
      case value
      when nil then :null
      when true, false then :boolean
      when Numeric then :number
      when String then :string
      when ActiveSupport::Duration then :duration
      when Date, Time, ActiveSupport::TimeWithZone then :temporal
      when Array then :list
      when Hash, Scope then :context
      when Function, Proc, Method then :function
      else :other
      end
    end

    def feel_equal(left, right)
      if left.is_a?(Array) && right.is_a?(Array)
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
      return nil if left.nil? || right.nil?
      return nil if left == true || left == false || right == true || right == false

      left.public_send(operator, right)
    rescue ArgumentError, NoMethodError, TypeError
      nil
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
      return true if value.is_a?(Array) && value.any? { |item| feel_equal(item, input) }

      equal = feel_equal_or_nil(input, value)
      return true if equal == true
      return false if value == false || value.is_a?(Array)

      equal
    end
  end

  #
  # FEEL numbers. Decimal literals are parsed as BigDecimal so arithmetic is
  # exact; values coming from Ruby may also be Integer or Float. Results
  # handed back to Ruby are normalized with `Numbers.normalize`.
  #
  module Numbers
    # Precision used for non-terminating divisions (like IEEE 754 decimal128).
    DIVISION_PRECISION = 34

    module_function

    # True for FEEL numbers (ActiveSupport::Duration pretends to be Numeric).
    def number?(value)
      value.is_a?(Numeric) && !value.is_a?(ActiveSupport::Duration)
    end

    # Converts a Ruby number into an exact FEEL number (Integer or BigDecimal).
    # Returns nil for non-numbers and for NaN / infinite values.
    def decimal(value)
      case value
      when Integer then value
      when BigDecimal then value.finite? ? value : nil
      when Float then value.finite? ? BigDecimal(value.to_s) : nil
      when Rational then BigDecimal(value, DIVISION_PRECISION)
      end
    end

    # Converts a FEEL result for Ruby callers: BigDecimal (and Rational) become
    # an Integer when integral, otherwise a Float. NaN and infinite values
    # become nil. Arrays and Hashes are normalized recursively.
    def normalize(value)
      case value
      when BigDecimal, Rational, Float
        return nil if value.respond_to?(:finite?) && !value.finite?
        return value if value.is_a?(Float)

        value == value.truncate ? value.to_i : value.to_f
      when Array then value.map { |item| normalize(item) }
      when Hash then value.transform_values { |item| normalize(item) }
      else value
      end
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
      return numeric_operation(left, right) { |l, r| l + r } if Numbers.number?(left) && Numbers.number?(right)
      return nil if left.nil? || right.nil?
      return nil if left.is_a?(Array) || right.is_a?(Array) || left.is_a?(Hash) || right.is_a?(Hash)
      return nil if left.is_a?(String) ^ right.is_a?(String)

      left + right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def subtract(left, right)
      return numeric_operation(left, right) { |l, r| l - r } if Numbers.number?(left) && Numbers.number?(right)
      return nil if left.nil? || right.nil?
      return nil if left.is_a?(String) || right.is_a?(String) || left.is_a?(Array) || right.is_a?(Array)
      return (left - right).to_i.days if left.instance_of?(Date) && right.instance_of?(Date)

      left - right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def multiply(left, right)
      return numeric_operation(left, right) { |l, r| l * r } if Numbers.number?(left) && Numbers.number?(right)
      return nil unless numeric_or_duration?(left) && numeric_or_duration?(right)
      return nil if left.is_a?(ActiveSupport::Duration) && right.is_a?(ActiveSupport::Duration)

      Numbers.normalize(left) * Numbers.normalize(right)
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def divide(left, right)
      return numeric_operation(left, right) { |l, r| decimal_divide(l, r) } if Numbers.number?(left) && Numbers.number?(right)
      return nil unless numeric_or_duration?(left) && numeric_or_duration?(right)
      return nil if right.is_a?(Numeric) && right.zero?
      return nil if left.is_a?(Numeric) && right.is_a?(ActiveSupport::Duration)

      left / Numbers.normalize(right)
    rescue ArgumentError, NoMethodError, TypeError, ZeroDivisionError
      nil
    end

    def numeric_or_duration?(value)
      value.is_a?(Numeric) || value.is_a?(ActiveSupport::Duration)
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
      return left / right if left.is_a?(Integer) && right.is_a?(Integer) && (left % right).zero?

      BigDecimal(left).div(right, Numbers::DIVISION_PRECISION)
    end
  end
end
