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

    # The names of the functions the expression invokes (see
    # FEEL::AST.functions).
    def named_functions(builtins: true)
      return [] if text.nil? || text.empty?

      AST.functions(tree.to_ast, builtins: builtins)
    end

    # The variables the expression depends on, e.g. "person.age" (see
    # FEEL::AST.variables for the paths, e.g. `["person", "age"]`).
    def named_variables
      return [] if text.nil? || text.empty?

      AST.variables(tree.to_ast).map { |path| path.join(".") }
    end

    # The built-in functions by name: the standard DMN functions and, unless
    # `config.camunda_extensions` is false, the extensions of Camunda
    # (Builtins::CAMUNDA_EXTENSIONS).
    def self.builtin_functions(camunda_extensions: FEEL.config.camunda_extensions)
      camunda_extensions ? all_builtin_functions : standard_builtin_functions
    end

    def self.all_builtin_functions
      @all_builtin_functions ||= (
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

    def self.standard_builtin_functions
      @standard_builtin_functions ||= all_builtin_functions.except(*Builtins::CAMUNDA_EXTENSIONS).freeze
    end

    def as_json
      {
        id: id,
        text: text,
      }
    end
  end
end
