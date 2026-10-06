# frozen_string_literal: true

module FEEL
  # The abstract syntax tree of FEEL expressions and unary tests, as plain
  # Hashes (see FEEL::AST.from_text and FEEL::AST.to_text). Each node has a `:type` and
  # its own keys; the format is documented in the README.
  module AST
    module_function

    # Yields each node of the tree (depth-first, parents before children).
    def walk(node, &block)
      return enum_for(:walk, node) unless block

      case node
      when Array then node.each { |child| walk(child, &block) }
      when Hash
        yield node if node.key?(:type)
        node.each_value { |child| walk(child, &block) }
      end
      nil
    end

    # Rebuilds the tree bottom-up: each node (with transformed children) is
    # replaced by the result of the block.
    #
    #   FEEL::AST.transform(ast) { |node| node[:type] == "name" ? node.merge(path: ["x"]) : node }
    def transform(node, &block)
      case node
      when Array then node.map { |child| transform(child, &block) }
      when Hash
        result = node.transform_values { |child| transform(child, &block) }
        result.key?(:type) ? yield(result) : result
      else node
      end
    end

    # Returns the AST of an expression, or of unary tests (e.g. `< 10, [20..30]`,
    # `not("A")` or `-`) with `unary_tests: true`:
    #
    #   FEEL::AST.from_text("age >= 18")
    #   # => { type: "comparison", operator: ">=",
    #   #      left: { type: "name", path: ["age"] }, right: { type: "number", value: 18 } }
    #
    # Raises FEEL::SyntaxError if the text is not valid.
    def from_text(text, unary_tests: false)
      (unary_tests ? FEEL.compile_test(text) : FEEL.compile(text)).tree.to_ast
    end

    # Builds the text of an expression or unary tests from an AST as returned
    # by FEEL::AST.from_text (symbol or string keys):
    #
    #   FEEL::AST.to_text({ type: "comparison", operator: ">=",
    #                       left: { type: "name", path: ["age"] }, right: { type: "number", value: 18 } })
    #   # => "age >= 18"
    #
    # Raises FEEL::AST::Error if the AST is not valid.
    def to_text(ast)
      Generator.new.generate(ast)
    end

    def range(start, finish, start_included, end_included)
      { type: "range", start: start, end: finish, start_included: start_included, end_included: end_included }
    end

    def arguments(params)
      return { arguments: [] } if params.empty?
      return { arguments: params.expressions.map(&:to_ast) } if params.is_a?(PositionalParameters)

      {
        named_arguments: params.parameters.map do |parameter|
          { name: parameter.parameter_name.eval, value: parameter.value.to_ast }
        end,
      }
    end

    def iterations(contexts)
      contexts.map { |context| { name: context.variable.eval, in: context.domain.to_ast } }
    end

    # Folds `head (op operand)*` into left-nested binary nodes.
    def fold(head, operations)
      operations.inject(head.to_ast) do |left, (operator, operand)|
        { type: "arithmetic", operator: operator, left: left, right: operand.to_ast }
      end
    end
  end

  class Node
    def to_ast
      raise NotImplementedError, "No AST for #{self.class.name}"
    end
  end

  class Root
    def to_ast
      expr.to_ast
    end
  end

  class UnaryTestRoot
    def to_ast
      expr.to_ast
    end
  end

  class Parenthesized
    def to_ast
      expr.to_ast
    end
  end

  class AnyUnaryTest
    def to_ast
      { type: "any" }
    end
  end

  class UnaryTestsRoot
    def to_ast
      { type: "unary tests", tests: tests.to_ast }
    end
  end

  class NegatedUnaryTests
    def to_ast
      { type: "not", tests: tests.to_ast }
    end
  end

  class PositiveUnaryTests
    def to_ast
      unary_tests.map(&:to_ast)
    end
  end

  # An expression as a test (compared with the input value) is represented
  # by the expression itself.
  class ExpressionUnaryTest
    def to_ast
      expr.to_ast
    end
  end

  class UnaryComparison
    def to_ast
      { type: "unary comparison", operator: operator_text, value: endpoint.to_ast }
    end
  end

  class Interval
    def to_ast
      AST.range(low.to_ast, high.to_ast, start_token.text_value == "[", end_token.text_value == "]")
    end
  end

  class RangeLiteral
    def to_ast
      AST.range(low.to_ast, high.to_ast, start_token.text_value == "[", end_token.text_value == "]")
    end
  end

  class OpenRangeLiteral
    def to_ast
      value = endpoint.to_ast
      case operator.text_value
      when "<" then AST.range(nil, value, false, false)
      when "<=" then AST.range(nil, value, false, true)
      when ">" then AST.range(value, nil, false, false)
      when ">=" then AST.range(value, nil, true, false)
      end
    end
  end

  # The integer range of a for expression, e.g. `for i in 1..3 return i`.
  class RangeExpression
    def to_ast
      AST.range(low.to_ast, high.to_ast, true, true)
    end
  end

  class FunctionDefinition
    def to_ast
      parameters = formal_parameters.empty? ? [] : formal_parameters.to_ast
      { type: "function definition", parameters: parameters, body: body.to_ast }
    end
  end

  class FormalParameterList
    def to_ast
      ([head] + tail.elements.map(&:formal_parameter)).map do |parameter|
        annotation = parameter.type_annotation
        type = annotation.empty? ? nil : annotation.type_name.text_value.gsub(/\s+/, " ")
        { name: parameter.parameter_name.eval, type: type }
      end
    end
  end

  class ForExpression
    def to_ast
      { type: "for", iterations: AST.iterations(iteration_contexts), return: body.to_ast }
    end
  end

  class QuantifiedExpression
    def to_ast
      { type: quantifier.text_value, iterations: AST.iterations(iteration_contexts), satisfies: condition.to_ast }
    end
  end

  class IfExpression
    def to_ast
      { type: "if", condition: condition.to_ast, then: true_case.to_ast, else: false_case.to_ast }
    end
  end

  class Disjunction
    def to_ast
      { type: "disjunction", operands: operands.map(&:to_ast) }
    end
  end

  class Conjunction
    def to_ast
      { type: "conjunction", operands: operands.map(&:to_ast) }
    end
  end

  class Comparison
    def to_ast
      { type: "comparison", operator: operator.text_value, left: left.to_ast, right: right.to_ast }
    end
  end

  class Between
    def to_ast
      { type: "between", value: value.to_ast, low: low.to_ast, high: high.to_ast }
    end
  end

  class InExpression
    def to_ast
      list = tests.to_ast
      { type: "in", value: value.to_ast, tests: list.is_a?(Array) ? list : [list] }
    end
  end

  class InstanceOf
    def to_ast
      { type: "instance of", value: value.to_ast, of: type.text_value.gsub(/\s+/, " ") }
    end
  end

  class Addition
    def to_ast
      AST.fold(head, operations.map { |plus, operand| [plus ? "+" : "-", operand] })
    end
  end

  class Multiplication
    def to_ast
      AST.fold(head, operations.map { |times, operand| [times ? "*" : "/", operand] })
    end
  end

  class Exponentiation
    def to_ast
      AST.fold(head, tail.elements.map { |element| ["**", element.operand] })
    end
  end

  class ArithmeticNegation
    def to_ast
      { type: "negation", value: operand.to_ast }
    end
  end

  class PostfixExpression
    def to_ast
      operations.inject(head.to_ast) { |value, operation| operation.to_ast(value) }
    end
  end

  class PathOperation
    def to_ast(value)
      { type: "path", value: value, property: property.respond_to?(:eval) ? property.eval : property.text_value }
    end
  end

  class FilterOperation
    def to_ast(value)
      { type: "filter", value: value, filter: filter_expression.to_ast }
    end
  end

  class InvocationOperation
    def to_ast(function)
      { type: "invocation", function: function }.merge(AST.arguments(params))
    end
  end

  class InputValue
    def to_ast
      { type: "input" }
    end
  end

  class FunctionInvocation
    def to_ast
      name = fn_name.is_a?(QualifiedName) ? fn_name.path.join(".") : function_name
      { type: "function call", name: name }.merge(AST.arguments(params))
    end
  end

  class QualifiedName
    def path
      [head_name] + path_keys.map(&:first)
    end

    def to_ast
      { type: "name", path: path }
    end
  end

  class StringLiteral
    def to_ast
      { type: "string", value: value }
    end
  end

  class BooleanLiteral
    def to_ast
      { type: "boolean", value: eval }
    end
  end

  class NumericLiteral
    def to_ast
      { type: "number", value: Numbers.normalize(eval) }
    end
  end

  class NullLiteral
    def to_ast
      { type: "null" }
    end
  end

  class AtLiteral
    def to_ast
      { type: "temporal", text: string_literal.value, value: Numbers.normalize(eval) }
    end
  end

  class List
    def to_ast
      { type: "list", items: expressions.map(&:to_ast) }
    end
  end

  class ContextLiteral
    def to_ast
      { type: "context", entries: entries.map { |entry| { key: entry.key_value, value: entry.value.to_ast } } }
    end
  end
end
