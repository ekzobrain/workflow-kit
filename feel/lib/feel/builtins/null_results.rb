# frozen_string_literal: true

module FEEL
  module Builtins
    #
    # The built-in functions that may return null for valid, non-null
    # arguments (e.g. `max([])`, `get value(context, "absent")`, `sqrt(-1)`).
    # Any other built-in function that returns null for non-null arguments
    # couldn't use them (see FEEL::Diagnostics). Each check returns nil if
    # the arguments are valid, otherwise [reason, problem].
    #
    module NullResults
      module_function

      def items(args)
        ListSupport.varargs(args) || []
      end

      def comparable_items(*args)
        list = items(args)
        list.empty? || ListSupport.comparable?(list) ? nil : [:invalid_argument, "the items can't be compared"]
      end

      def number_items(*args)
        ListSupport.numbers?(items(args)) ? nil : [:invalid_argument, "the items must be numbers"]
      end

      def number(value, *)
        Numbers.number?(value) ? nil : [:invalid_argument, "a number is expected"]
      end
    end

    NULL_RESULTS = {
      "get value" => ->(context = nil, key = nil, *) {
        next [:invalid_argument, "a context is expected"] unless ContextSupport.context?(context)

        ContextSupport.key_path(key) ? nil : [:invalid_argument, "a key or a list of keys is expected"]
      },
      "min" => NullResults.method(:comparable_items),
      "max" => NullResults.method(:comparable_items),
      "sum" => NullResults.method(:number_items),
      "product" => NullResults.method(:number_items),
      "mean" => NullResults.method(:number_items),
      "median" => NullResults.method(:number_items),
      "stddev" => NullResults.method(:number_items),
      "sqrt" => NullResults.method(:number),
      "log" => NullResults.method(:number),
      "modulo" => ->(dividend = nil, divisor = nil, *) {
        next [:division_by_zero, "division by zero"] if Numbers.number?(dividend) && Numbers.number?(divisor) && divisor.zero?

        [:invalid_argument, "numbers are expected"]
      },
      "from json" => ->(json = nil, *) {
        json.is_a?(String) && json.strip == "null" ? nil : [:invalid_argument, "not a valid JSON text"]
      },
      # these report their own failures, or return null only for null
      "assert" => ->(*) {},
      "get or else" => ->(*) {},
      "string" => ->(*) {},
    }.freeze
  end
end
