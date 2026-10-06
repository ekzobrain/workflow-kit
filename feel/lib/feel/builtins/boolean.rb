# frozen_string_literal: true

module FEEL
  module Builtins
    #
    # is(value1, value2) of DMN: true if both values are the same element of
    # the FEEL semantic domain, i.e. of the same type and equal. Unlike `=`,
    # times and date-times must also have the same offset and zone, and a
    # local time is not the same as a time with offset.
    #
    module Sameness
      extend Values

      module_function

      def same?(left, right)
        left = Temporal.normalize(left)
        right = Temporal.normalize(right)
        return left.nil? && right.nil? if left.nil? || right.nil?

        case left
        when Array then right.is_a?(Array) && left.length == right.length && left.zip(right).all? { |l, r| same?(l, r) }
        when Hash, Scope then same_context?(left, right)
        when FEEL::Range then same_range?(left, right)
        when Function, Proc, Method then left.equal?(right)
        else
          return same_temporal?(left, right) if Temporal.temporal?(left)

          type_kind(left) == type_kind(right) && feel_equal(left, right)
        end
      end

      def same_context?(left, right)
        return false unless right.is_a?(Hash) || right.is_a?(Scope)

        left = left.to_h.transform_keys(&:to_s)
        right = right.to_h.transform_keys(&:to_s)
        left.keys.sort == right.keys.sort && left.all? { |key, value| same?(value, right[key]) }
      end

      def same_range?(left, right)
        right.is_a?(FEEL::Range) && same?(left.start, right.start) && same?(left.end, right.end) &&
          left.start_included == right.start_included && left.end_included == right.end_included
      end

      def same_temporal?(left, right)
        return false unless Temporal.kind(left) == Temporal.kind(right)

        case left
        when LocalTime, ZonedTime, LocalDateTime, Duration then left.class == right.class && left == right
        when Time
          right.is_a?(Time) && left == right && left.utc_offset == right.utc_offset &&
            Temporal.zone_id(left) == Temporal.zone_id(right)
        else left == right
        end
      end
    end

    BOOLEAN = {
      "not": ->(negand) {
        !negand if negand == true || negand == false
      },
      "is": ->(value1, value2) {
        Sameness.same?(value1, value2)
      },
      "is defined": ->(value) {
        !value.nil?
      },
      "get or else": ->(value, default) {
        value.nil? ? default : value
      },
      # Returns the value if the condition is true. Otherwise, the evaluation
      # fails: in strict mode an EvaluationError is raised, otherwise the
      # result is null.
      "assert": ->(value, condition, cause = nil) {
        return value if condition == true
        raise EvaluationError, (cause.is_a?(String) ? cause : "The condition is not fulfilled") if FEEL.config.strict

        nil
      },
    }.freeze
  end
end
