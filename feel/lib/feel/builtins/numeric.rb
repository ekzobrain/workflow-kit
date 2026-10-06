# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

module FEEL
  module Builtins
    #
    # Helpers for the numeric built-in functions.
    #
    module NumericHelpers
      ROUNDING_MODES = {
        "UP" => :up,
        "DOWN" => :down,
        "CEILING" => :ceiling,
        "FLOOR" => :floor,
        "HALF_UP" => :half_up,
        "HALF_DOWN" => :half_down,
        "HALF_EVEN" => :half_even,
        "UNNECESSARY" => :unnecessary,
      }.freeze

      module_function

      # Exact FEEL number (Integer or BigDecimal), or nil for non-numbers.
      def number(value)
        Numbers.decimal(value) if Numbers.number?(value)
      end

      # Rounds a number to the given scale with a rounding mode (see
      # java.math.RoundingMode). Returns nil for invalid arguments or if the
      # mode is UNNECESSARY and rounding is required.
      def round(n, scale, mode)
        n = number(n)
        scale = number(scale)
        return if n.nil? || scale.nil? || mode.nil?

        n = BigDecimal(n)
        scale = scale.to_i
        if mode == :unnecessary
          rounded = n.round(scale, :down)
          rounded == n ? rounded : nil
        else
          n.round(scale, mode)
        end
      end

      # Applies a Float math function, returning an exact FEEL number.
      def math(n)
        n = number(n)
        return if n.nil?

        Numbers.decimal(yield(n.to_f))
      rescue Math::DomainError
        nil
      end
    end

    NUMERIC = {
      "decimal": ->(n, scale, mode = "HALF_EVEN") {
        return unless mode.is_a?(String)
        NumericHelpers.round(n, scale, NumericHelpers::ROUNDING_MODES[mode.upcase])
      },
      "floor": ->(n, scale = 0) {
        NumericHelpers.round(n, scale, :floor)
      },
      "ceiling": ->(n, scale = 0) {
        NumericHelpers.round(n, scale, :ceiling)
      },
      "round up": ->(n, scale) {
        NumericHelpers.round(n, scale, :up)
      },
      "round down": ->(n, scale) {
        NumericHelpers.round(n, scale, :down)
      },
      "round half up": ->(n, scale) {
        NumericHelpers.round(n, scale, :half_up)
      },
      "round half down": ->(n, scale) {
        NumericHelpers.round(n, scale, :half_down)
      },
      # The parameter can be named `number` or `n`.
      "abs": ->(number = nil, n = nil) {
        return unless number.nil? ^ n.nil?
        value = number.nil? ? n : number
        case value
        when ActiveSupport::Duration then Temporal.abs(value)
        when Numeric then NumericHelpers.number(value)&.abs
        end
      },
      "modulo": ->(dividend, divisor) {
        dividend = NumericHelpers.number(dividend)
        divisor = NumericHelpers.number(divisor)
        return if dividend.nil? || divisor.nil? || divisor.zero?
        # Ruby's modulo has the sign of the divisor, as FEEL requires.
        dividend % divisor
      },
      "sqrt": ->(number) {
        return if !number.is_a?(Numeric) || number.negative?
        NumericHelpers.math(number) { |x| Math.sqrt(x) }
      },
      "log": ->(number) {
        return if !number.is_a?(Numeric) || !number.positive?
        NumericHelpers.math(number) { |x| Math.log(x) }
      },
      "exp": ->(number) {
        NumericHelpers.math(number) { |x| Math.exp(x) }
      },
      "odd": ->(number) {
        number = NumericHelpers.number(number)
        return if number.nil?
        number.abs % 2 == 1
      },
      "even": ->(number) {
        number = NumericHelpers.number(number)
        return if number.nil?
        number % 2 == 0
      },
      "random number": -> {
        rand
      },
    }.freeze
  end
end
