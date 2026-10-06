# frozen_string_literal: true

module FEEL
  class LiteralExpression
    attr_reader :id, :text

    def self.from_json(json)
      LiteralExpression.new(id: json[:id], text: json[:text])
    end

    def initialize(id: nil, text:)
      @id = id
      @text = text&.strip
    end

    def tree
      @tree ||= FEEL::Parser.parse(text)
    end

    def valid?
      return false if text.blank?
      tree.present?
    rescue SyntaxError
      false
    end

    def evaluate(variables = {})
      tree.eval(functions.merge(variables))
    end

    def functions
      builtins = LiteralExpression.builtin_functions
      custom = (FEEL.config.functions || {})
      ActiveSupport::HashWithIndifferentAccess.new(builtins.merge(custom))
    end

    def named_functions
      return [] if text.blank?

      function_names = Set.new
      walk_tree(tree) do |node, _bound_names|
        function_names << node.function_name if node.is_a?(FEEL::FunctionInvocation)
      end
      function_names.to_a
    end

    def named_variables
      return [] if text.blank?

      qualified_names = Set.new
      walk_tree(tree) do |node, bound_names|
        next unless node.is_a?(FEEL::QualifiedName)
        next if bound_names.include?(node.head.eval)

        qualified_names << node.text_value.gsub(/\s+/, "")
      end
      qualified_names.to_a
    end

    # Walks the tree, yielding each node with the names bound by enclosing
    # for/quantified expressions, filters and function definitions.
    def walk_tree(node, bound_names = Set.new, &block)
      bound_names = bound_names | node.local_names if node.respond_to?(:local_names)
      bound_names = bound_names | node.parameter_names if node.is_a?(FEEL::FunctionDefinition)
      yield node, bound_names

      node.elements&.each { |child| walk_tree(child, bound_names, &block) }
    end

    def self.builtin_functions
      @builtin_functions ||= HashWithIndifferentAccess.new(
        Builtins::CONVERSION
          .merge(Builtins::BOOLEAN)
          .merge(Builtins::STRING)
          .merge(Builtins::NUMERIC)
          .merge(Builtins::LIST)
          .merge(Builtins::CONTEXT)
          .merge(Builtins::TEMPORAL),
      )
    end

    def as_json
      {
        id: id,
        text: text,
      }
    end
  end
end
