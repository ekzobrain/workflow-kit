# frozen_string_literal: true

module BPMN
  # Raised while reading a BPMN definition with an invalid FEEL expression.
  # A FEEL::SyntaxError, so `rescue FEEL::Error` also catches it.
  class SyntaxError < FEEL::SyntaxError
    attr_reader :element_id, :attribute, :expression

    def initialize(message = nil, element_id: nil, attribute: nil, expression: nil)
      super(message)
      @element_id = element_id
      @attribute = attribute
      @expression = expression
    end
  end

  # The value of an attribute that may be a FEEL expression: a text starting
  # with "=" is an expression, compiled once (when the definition is read),
  # anything else is a static value.
  class Expression
    attr_reader :text

    def self.compile(text, element: nil, attribute: nil)
      text.nil? ? nil : new(text, element: element, attribute: attribute)
    end

    def initialize(text, element: nil, attribute: nil)
      @text = text
      @feel = FEEL.compile(text.delete_prefix("=")) if text.is_a?(String) && text.start_with?("=")
    rescue FEEL::SyntaxError
      location = [attribute, element&.id && "of element #{element.id.inspect}"].compact.join(" ")
      raise SyntaxError.new("Invalid expression#{" in #{location}" unless location.empty?}: #{text.inspect}",
        element_id: element&.id, attribute: attribute, expression: text)
    end

    def expression?
      !@feel.nil?
    end

    def evaluate(variables = {})
      @feel ? @feel.evaluate(variables) : text
    end
  end
end
