# frozen_string_literal: true

require "json"
require "bigdecimal"

module FEEL
  module Builtins
    #
    # Formatting of FEEL values as strings, used by the conversion built-ins
    # `string()` and `to json()`. Follows the formats of feel-scala.
    #
    module ConversionFormat
      module_function

      NUMBER_PATTERN = /\A[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?\z/
      GROUPING_SEPARATORS = [" ", ",", "."].freeze
      DECIMAL_SEPARATORS = [",", "."].freeze
      YEAR_MONTH_PARTS = %i[years months].freeze

      # Parses a number string. Returns an Integer if integral, otherwise a Float.
      def parse_number(text)
        return unless text.is_a?(String) && text.match?(NUMBER_PATTERN)

        decimal = BigDecimal(text)
        decimal.frac.zero? ? decimal.to_i : decimal.to_f
      rescue ArgumentError
        nil
      end

      # The string representation of a value as returned by `string()`.
      # Strings nested in lists and contexts are quoted.
      def to_feel_string(value, nested: false)
        case value
        when nil then "null"
        when String then nested ? "\"#{value}\"" : value
        when true, false then value.to_s
        when Numeric then format_number(value)
        when Array then "[#{value.map { |item| to_feel_string(item, nested: true) }.join(", ")}]"
        when Hash, Scope then "{#{context_entries(value).map { |k, v| "#{k}:#{to_feel_string(v, nested: true)}" }.join(", ")}}"
        when FEEL::Range then value.to_feel_string { |endpoint| to_feel_string(endpoint, nested: true) }
        when ->(v) { Temporal.temporal?(v) } then Temporal.format_value(value)
        when Function, Proc, Method then format_function(value)
        else value.to_s
        end
      end

      # Converts a value into a structure that can be serialized to JSON.
      def to_json_value(value)
        case value
        when nil, String, true, false, Integer then value
        when BigDecimal then value.frac.zero? ? value.to_i : value.to_f
        when Float then value.finite? ? value : nil
        when Rational then value.to_f
        when Array then value.map { |item| to_json_value(item) }
        when Hash, Scope then context_entries(value).to_h { |k, v| [k, to_json_value(v)] }
        when FEEL::Range then value.to_feel_string { |endpoint| to_feel_string(endpoint, nested: true) }
        when ActiveSupport::Duration then format_java_duration(value)
        when ->(v) { Temporal.temporal?(v) } then Temporal.format_iso(value)
        when Function, Proc, Method then format_function(value)
        else to_feel_string(value)
        end
      end

      def context_entries(context)
        context.to_h.map { |key, value| [key.to_s, value] }
      end

      def format_number(number)
        case number
        when Integer then number.to_s
        when BigDecimal then number.frac.zero? ? number.to_i.to_s : number.to_s("F")
        when Float
          return number.to_s unless number.finite?

          text = number.to_s
          text.include?("e") ? BigDecimal(text).to_s("F").sub(/\.0\z/, "") : text
        when Rational then format_number(BigDecimal(number, 34))
        else number.to_s
        end
      end

      def format_function(function)
        params = if function.is_a?(Function)
          function.params
        else
          function.parameters.map { |_type, name| name.to_s.tr("_", " ") }
        end
        "function(#{params.join(", ")})"
      end

      def year_month_duration?(duration)
        parts = duration.parts.reject { |_part, amount| amount.zero? }
        if parts.empty?
          duration.parts.any? && duration.parts.keys.all? { |part| YEAR_MONTH_PARTS.include?(part) }
        else
          parts.keys.all? { |part| YEAR_MONTH_PARTS.include?(part) }
        end
      end

      def total_months(duration)
        (duration.parts[:years] || 0) * 12 + (duration.parts[:months] || 0)
      end

      def total_seconds(duration)
        parts = duration.parts
        seconds = (parts[:weeks] || 0) * 604_800 +
          (parts[:days] || 0) * 86_400 +
          (parts[:hours] || 0) * 3600 +
          (parts[:minutes] || 0) * 60 +
          BigDecimal((parts[:seconds] || 0).to_s)
        seconds.frac.zero? ? seconds.to_i : seconds
      end

      # ISO-8601 format of java.time Period/Duration: "P1Y6M", "PT2H30M", "PT26H".
      def format_java_duration(duration)
        if year_month_duration?(duration)
          months = total_months(duration)
          return "P0D" if months.zero?

          years = months.abs / 12 * (months <=> 0)
          months = months.abs % 12 * (months <=> 0)
          "P#{amount(years, "Y")}#{amount(months, "M")}"
        elsif duration.parts.any? { |part, _| YEAR_MONTH_PARTS.include?(part) }
          duration.iso8601
        else
          seconds = total_seconds(duration)
          return "PT0S" if seconds.zero?

          sign = seconds.negative? ? -1 : 1
          hours, rest = seconds.abs.divmod(3600)
          minutes, seconds = rest.divmod(60)
          "PT#{amount(sign * hours, "H")}#{amount(sign * minutes, "M")}#{amount(sign * seconds, "S")}"
        end
      end

      def amount(value, designator)
        return "" if value.zero?

        "#{format_number(value)}#{designator}"
      end
    end

    CONVERSION = {
      "string": ->(from) {
        return if from.nil?
        ConversionFormat.to_feel_string(from)
      },
      "number": ->(from, grouping_separator = nil, decimal_separator = nil) {
        return unless from.is_a?(String)
        return if grouping_separator && !ConversionFormat::GROUPING_SEPARATORS.include?(grouping_separator)
        return if decimal_separator && !ConversionFormat::DECIMAL_SEPARATORS.include?(decimal_separator)
        return if grouping_separator && grouping_separator == decimal_separator

        text = from
        text = text.delete(grouping_separator) if grouping_separator
        text = text.tr(decimal_separator, ".") if decimal_separator
        ConversionFormat.parse_number(text)
      },
      "from json": ->(json) {
        return unless json.is_a?(String)
        begin
          JSON.parse(json)
        rescue JSON::ParserError
          nil
        end
      },
      "to json": ->(value) {
        begin
          JSON.generate(ConversionFormat.to_json_value(value))
        rescue JSON::GeneratorError, TypeError
          nil
        end
      },
    }.freeze
  end
end
