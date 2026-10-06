# frozen_string_literal: true

module FEEL
  # Base class of all errors raised by the gem: `rescue FEEL::Error`.
  class Error < StandardError; end

  # An expression or unary tests text is not valid.
  class SyntaxError < Error; end

  # An expression can't be evaluated (only raised in strict mode, otherwise
  # the result is null).
  class EvaluationError < Error; end

  # A value can't be serialized (FEEL.serialize) or deserialized
  # (FEEL.deserialize).
  class SerializationError < Error; end

  module AST
    # An AST can't be turned into text (FEEL::AST.to_feel).
    class Error < FEEL::Error; end
  end
end
