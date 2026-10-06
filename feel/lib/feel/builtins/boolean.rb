# frozen_string_literal: true

module FEEL
  module Builtins
    BOOLEAN = {
      "not": ->(negand) {
        !negand if negand == true || negand == false
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
