# frozen_string_literal: true

module FEEL
  # Base class of all errors raised by the gem: `rescue FEEL::Error`.
  class Error < StandardError; end

  # An expression or unary tests text is not valid.
  class SyntaxError < Error; end

  # An expression can't be evaluated (only raised in strict mode, otherwise
  # the result is null). `reason` tells why (see FEEL::Diagnostics), and
  # `expression` / `position` which part of the expression failed.
  class EvaluationError < Error
    attr_accessor :reason, :expression, :position

    def initialize(message = nil, reason: nil, expression: nil, position: nil)
      super(message)
      @reason = reason
      @expression = expression
      @position = position
    end
  end

  # A value can't be serialized (FEEL.serialize) or deserialized
  # (FEEL.deserialize).
  class SerializationError < Error; end

  module AST
    # An AST can't be turned into text (FEEL::AST.to_text).
    class Error < FEEL::Error; end
  end
end
