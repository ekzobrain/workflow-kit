# frozen_string_literal: true

module FEEL
  module AST
    # Finds the variables and functions an AST depends on (see
    # FEEL::AST.variables and FEEL::AST.functions), following the scoping
    # rules of FEEL: names bound inside the expression (iteration variables,
    # `partial`, function parameters, context entries, `item` and the entries
    # of filtered contexts) are not dependencies.
    class Analyzer
      attr_reader :variables, :functions

      def initialize(ast)
        @variables = []
        @functions = []
        visit(ast, Set.new, Set.new)
        @variables.uniq!
        @functions.uniq!
      end

      private

      # `bound` are the names visible at the node, `deferred` the names only
      # visible in function bodies: the entries of an enclosing context, which
      # a function can reference (e.g. recursively) once the context is built.
      def visit(value, bound, deferred)
        case value
        when Array then value.each { |item| visit(item, bound, deferred) }
        when Hash
          if type(value)
            visit_node(value, bound, deferred)
          else
            value.each_value { |item| visit(item, bound, deferred) }
          end
        end
      end

      def visit_node(node, bound, deferred)
        case type(node)
        when "name"
          path = Array(get(node, :path))
          @variables << path unless path.empty? || bound.include?(path.first)
        when "function call"
          visit_function_call(node, bound, deferred)
        when "path"
          visit(get(node, :value), bound, deferred)
        when "filter"
          visit(get(node, :value), bound, deferred)
          visit(get(node, :filter), bound | filter_names(get(node, :value)), deferred)
        when "for"
          scope = visit_iterations(node, bound, deferred)
          visit(get(node, :return), scope | ["partial"], deferred)
        when "some", "every"
          visit(get(node, :satisfies), visit_iterations(node, bound, deferred), deferred)
        when "function definition"
          parameters = Array(get(node, :parameters)).map { |parameter| get(parameter, :name) }
          visit(get(node, :body), bound | deferred | parameters, deferred)
        when "context"
          visit_context(node, bound, deferred)
        else
          node.each_value { |item| visit(item, bound, deferred) }
        end
      end

      def visit_function_call(node, bound, deferred)
        path = get(node, :path)
        if path
          # `a.b(x)`: a function `a.b`, or the function in the variable `a.b`
          unless bound.include?(path.first)
            @variables << path[0...-1]
            @functions << get(node, :name)
          end
        else
          name = get(node, :name)
          @functions << name unless bound.include?(name)
        end
        visit(get(node, :arguments), bound, deferred)
        visit(get(node, :named_arguments), bound, deferred)
      end

      # Each iteration can use the variables of the previous ones.
      def visit_iterations(node, bound, deferred)
        Array(get(node, :iterations)).inject(bound) do |scope, iteration|
          visit(get(iteration, :in), scope, deferred)
          scope | [get(iteration, :name)]
        end
      end

      # An entry can use the previous entries, a function the whole context.
      def visit_context(node, bound, deferred)
        entries = Array(get(node, :entries))
        keys = entries.map { |entry| get(entry, :key) }.compact
        entries.each_with_object([]) do |entry, previous|
          visit(get(entry, :value), bound | previous, deferred | keys)
          key = get(entry, :key)
          previous << key unless key.nil?
        end
      end

      # A filter can use `item` and, for a list of context literals, their
      # entries.
      def filter_names(value)
        names = ["item"]
        return names unless type(value) == "list"

        Array(get(value, :items)).each do |item|
          next unless type(item) == "context"

          names.concat(Array(get(item, :entries)).map { |entry| get(entry, :key) }.compact)
        end
        names
      end

      def type(node)
        node.is_a?(Hash) ? get(node, :type) : nil
      end

      # Symbol or string keys (e.g. for an AST read from JSON).
      def get(node, key)
        node.key?(key) ? node[key] : node[key.to_s]
      end
    end
  end
end
