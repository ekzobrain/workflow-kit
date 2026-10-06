# frozen_string_literal: true

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
      when "number" then input.is_a?(Numeric)
      when "boolean" then input == true || input == false
      when "date", "time", "date and time", "duration", "years and months duration", "days and time duration"
        Temporal.instance_of_type?(input, type_text)
      when "context" then input.is_a?(Hash) || input.is_a?(Scope)
      when "function" then input.is_a?(Function) || input.is_a?(Proc) || input.is_a?(Method)
      when /\Alist\b/ then input.is_a?(Array)
      when /\Acontext\b/ then input.is_a?(Hash) || input.is_a?(Scope)
      when /\Afunction\b/ then input.is_a?(Function) || input.is_a?(Proc) || input.is_a?(Method)
      else false
      end
    end

    def type_kind(value)
      case value
      when nil then :null
      when true, false then :boolean
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
      return nil if left.nil? || right.nil?
      return nil if left == true || left == false || right == true || right == false
      return Temporal.compare(operator, left, right) if Temporal.temporal?(left) || Temporal.temporal?(right)

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
  # 4. arithmetic expression
  #
  module Arithmetic
    def add(left, right)
      return temporal_add(left, right) if temporal_operand?(left, right)
      return nil if left.nil? || right.nil?
      return nil if left.is_a?(Array) || right.is_a?(Array) || left.is_a?(Hash) || right.is_a?(Hash)
      return nil if left.is_a?(String) ^ right.is_a?(String)

      left + right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def subtract(left, right)
      return temporal_subtract(left, right) if temporal_operand?(left, right)
      return nil if left.nil? || right.nil?
      return nil if left.is_a?(String) || right.is_a?(String) || left.is_a?(Array) || right.is_a?(Array)

      left - right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def multiply(left, right)
      return temporal_multiply(left, right) if temporal_operand?(left, right)
      return nil unless numeric_or_duration?(left) && numeric_or_duration?(right)
      return nil if left.is_a?(ActiveSupport::Duration) && right.is_a?(ActiveSupport::Duration)

      left * right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    def divide(left, right)
      return temporal_divide(left, right) if temporal_operand?(left, right)
      return nil unless numeric_or_duration?(left) && numeric_or_duration?(right)
      return nil if right.is_a?(Numeric) && right.zero?
      return nil if left.is_a?(Numeric) && right.is_a?(ActiveSupport::Duration)

      if left.is_a?(Integer) && right.is_a?(Integer)
        (left % right).zero? ? left / right : left.fdiv(right)
      else
        left / right
      end
    rescue ArgumentError, NoMethodError, TypeError, ZeroDivisionError
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

    def numeric_or_duration?(value)
      value.is_a?(Numeric) || value.is_a?(ActiveSupport::Duration)
    end
  end
end
