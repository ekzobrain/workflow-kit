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
      return @valid if defined?(@valid)

      @valid = begin
        !text.nil? && !text.empty? && !tree.nil?
      rescue SyntaxError
        false
      end
    end

    def evaluate(variables = {})
      Numbers.normalize(tree.compiled.call(RootScope.build(variables)))
    end

    def functions
      builtins = LiteralExpression.builtin_functions
      custom = (FEEL.config.functions || {}).to_h.transform_keys(&:to_s)
      builtins.merge(custom)
    end

    def named_functions
      return [] if text.nil? || text.empty?

      function_names = Set.new
      walk_tree(tree) do |node, _bound_names|
        function_names << node.function_name if node.is_a?(FEEL::FunctionInvocation)
      end
      function_names.to_a
    end

    def named_variables
      return [] if text.nil? || text.empty?

      qualified_names = Set.new
      walk_tree(tree) do |node, bound_names|
        if node.is_a?(FEEL::FunctionInvocation)
          # the name of an invoked function is not a variable, but the path of
          # a qualified function name (e.g. `a.b(x)`) is
          fn_name = node.fn_name
          next unless fn_name.is_a?(FEEL::QualifiedName) && !fn_name.tail.empty?
          next if bound_names.include?(fn_name.head.eval)

          qualified_names << ([fn_name.head] + fn_name.tail.elements.map(&:name)[0...-1]).map { |n| n.respond_to?(:eval) ? n.eval : n.text_value }.join(".")
          next
        end
        next unless node.is_a?(FEEL::QualifiedName)
        next if function_name_node?(node)
        next if bound_names.include?(node.head.eval)

        qualified_names << node.text_value.gsub(/\s+/, "")
      end
      qualified_names.to_a
    end

    # Walks the tree, yielding each node with the names bound by enclosing
    # for/quantified expressions, filters, context literals and function
    # definitions.
    def walk_tree(node, bound_names = Set.new, &block)
      bound_names = bound_names | node.local_names if node.respond_to?(:local_names)
      bound_names = bound_names | node.parameter_names if node.is_a?(FEEL::FunctionDefinition)
      yield node, bound_names

      if node.is_a?(FEEL::PostfixExpression)
        # a filter on a list of context literals can access the context entries
        walk_tree(node.head, bound_names, &block)
        filter_names = bound_names | node.filter_local_names
        node.tail.elements.each { |child| walk_tree(child, filter_names, &block) }
      else
        node.elements&.each { |child| walk_tree(child, bound_names, &block) }
      end
    end

    private

    def function_name_node?(node)
      node.parent.is_a?(FEEL::FunctionInvocation) && node.parent.fn_name.equal?(node)
    end

    public

    def self.builtin_functions
      @builtin_functions ||= (
        Builtins::CONVERSION
          .merge(Builtins::BOOLEAN)
          .merge(Builtins::STRING)
          .merge(Builtins::NUMERIC)
          .merge(Builtins::LIST)
          .merge(Builtins::CONTEXT)
          .merge(Builtins::TEMPORAL)
          .merge(Builtins::RANGE)
      ).transform_keys(&:to_s).freeze
    end

    def as_json
      {
        id: id,
        text: text,
      }
    end
  end
end
