# frozen_string_literal: true

module FEEL
  #
  # Why an expression (or a part of it) can't be computed, recorded during an
  # evaluation: see FEEL.evaluate (`warnings:`) and the strict mode.
  #
  # Reasons:
  # - :unknown_variable  - a name is not in scope
  # - :no_context_entry  - a context has no entry with the key (`obj.missing`)
  # - :unknown_function  - no function with the name
  # - :arguments         - the arguments don't match the parameters (number, names)
  # - :type_mismatch     - operands of incompatible types, or a non-boolean
  #                        where a boolean is needed, or a non-list where a list is
  # - :invalid_argument  - a built-in function can't use its arguments
  # - :division_by_zero
  # - :not_a_context     - a path into a value that has no such property
  # - :assertion         - a failed `assert()`
  # - :function_failure  - a custom (Ruby) function raised an error
  # - :null_operand      - null as an operand or argument: the result is null,
  #                        as FEEL defines it (a warning only, never raised)
  #
  Warning = Struct.new(:reason, :message, :expression, :position, keyword_init: true) do
    def to_s = message
  end

  module Diagnostics
    # The state of the current evaluation (per thread / fiber).
    Evaluation = Struct.new(:strict, :warnings)

    KEY = :feel_evaluation

    # Reasons recorded as warnings but never raised in strict mode.
    WARNING_ONLY = %i[null_operand].freeze

    @evaluations = 0
    @mutex = Mutex.new
    @enabled = false

    class << self
      # Whether failures may have to be reported: strict mode is configured,
      # or an evaluation with options runs (in any thread). Checked first, so
      # that a lenient evaluation doesn't pay for the diagnostics.
      attr_reader :enabled

      def update
        @enabled = FEEL.config.strict || @evaluations.positive?
      end

      def started
        @mutex.synchronize do
          @evaluations += 1
          @enabled = true
        end
      end

      def ended
        @mutex.synchronize do
          @evaluations -= 1
          update
        end
      end
    end

    module_function

    OPTIONS = %i[strict warnings].freeze

    # Runs an evaluation with its own options (`strict:`, `warnings:`).
    def evaluating(options)
      options ||= {}
      unknown = options.keys - OPTIONS
      raise ArgumentError, "unknown option#{"s" if unknown.size > 1}: #{unknown.join(", ")}" unless unknown.empty?

      strict = options[:strict]
      previous = Thread.current[KEY]
      Thread.current[KEY] = Evaluation.new(strict.nil? ? FEEL.config.strict : strict, options[:warnings])
      Diagnostics.started
      begin
        yield
      ensure
        Diagnostics.ended
        Thread.current[KEY] = previous
      end
    end

    def strict?
      evaluation = Thread.current[KEY]
      evaluation ? evaluation.strict : FEEL.config.strict
    end

    # Records a failure of the node: adds a warning (if they are collected)
    # and, in strict mode, raises FEEL::EvaluationError (unless the reason is
    # a warning only or `raise_error` is false). The message is built (by the
    # block) only if needed. Returns nil, the result of the failed operation.
    def report(node, reason, raise_error: true)
      evaluation = Thread.current[KEY]
      strict = evaluation ? evaluation.strict : FEEL.config.strict
      warnings = evaluation&.warnings
      raising = strict && raise_error && !WARNING_ONLY.include?(reason)
      return nil unless raising || warnings

      message = yield
      position = node&.diagnostic_interval
      expression = node && node.input[position].strip
      warnings&.push(Warning.new(reason: reason, message: message, expression: expression, position: position))
      raise EvaluationError.new(message, reason: reason, expression: expression, position: position) if raising

      nil
    end

    # A short representation of a value for messages.
    def describe(value)
      text = case value
      when nil then "null"
      when String then value.inspect
      when Function, Proc, Method then "a function"
      else Builtins::ConversionFormat.to_feel_string(value, nested: true)
      end
      text.length > 40 ? "#{text[0, 37]}..." : text
    rescue StandardError
      value.class.name
    end
  end
end
