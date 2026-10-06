# frozen_string_literal: true

module FEEL
  class Node < Treetop::Runtime::SyntaxNode
    include Values

    def contains_input_placeholder?(node = self)
      return true if node.is_a?(InputValue)
      return false unless node.elements

      node.elements.any? { |element| contains_input_placeholder?(element) }
    end

    #
    # Takes a context hash and returns an array of qualified names
    # { "person": { "name": { "first": "Eric", "last": "Carlson" }, "age": 60 } } => ["person", "person.name.first", "person.name.last", "person.age"]
    #
    def qualified_names_in_context(hash = {}, prefix = "", qualified_names = Set.new)
      hash.each do |key, value|
        new_prefix = prefix.empty? ? "#{key}" : "#{prefix}.#{key}"
        if value.is_a?(Hash)
          qualified_names_in_context(value, new_prefix, qualified_names)
        else
          qualified_names.add(new_prefix)
        end
      end if hash

      qualified_names.to_a
    end

    def raise_evaluation_error(missing_name, ctx = {})
      names = qualified_names_in_context(ctx)
      checker = DidYouMean::SpellChecker.new(dictionary: names)
      guess = checker.correct(missing_name)
      suffix = " Did you mean #{guess.first}?" unless guess.empty?
      raise EvaluationError.new("Identifier #{missing_name} not found.#{suffix}")
    end

    #

    #
    # Function invocation helpers
    #

    def invoke_function(fn, params_node, context)
      if params_node.is_a?(NamedParameters)
        invoke_with_named_parameters(fn, params_node.eval(context))
      else
        args = params_node.respond_to?(:eval) && !params_node.empty? ? params_node.eval(context) : []
        invoke_with_positional_parameters(fn, args)
      end
    end

    def invoke_with_positional_parameters(fn, args)
      return nil unless arity_matches?(fn, args.length)

      fn.call(*args)
    end

    def invoke_with_named_parameters(fn, named_args)
      return fn.call_named(named_args) if fn.is_a?(Function)
      return nil unless fn.respond_to?(:parameters)

      parameters = fn.parameters
      names = parameters.map { |_type, name| name.to_s }
      keys = named_args.keys.map { |key| key.to_s.tr(" ", "_") }
      return nil unless (keys - names).empty?

      args = parameters.each_with_index.map do |(_type, name), _index|
        named_args.find { |key, _value| key.to_s.tr(" ", "_") == name.to_s }&.last
      end
      args.pop while args.any? && args.last.nil? && optional_parameter?(parameters[args.length - 1])
      return nil unless arity_matches?(fn, args.length)

      fn.call(*args)
    end

    def optional_parameter?(parameter)
      parameter && parameter.first == :opt
    end

    def arity_matches?(fn, count)
      return count == fn.params.length if fn.is_a?(Function)
      return true unless fn.respond_to?(:lambda?) && fn.lambda?

      parameters = fn.parameters
      required = parameters.count { |type, _| type == :req }
      optional = parameters.count { |type, _| type == :opt }
      rest = parameters.any? { |type, _| type == :rest }
      count >= required && (rest || count <= required + optional)
    end

    def function_not_found(name, args_count, context)
      raise EvaluationError.new("No function found with name '#{name}' and #{args_count} parameters") if FEEL.config.strict
      nil
    end
  end

  #
  # Entry points
  #

  class Root < Node
    def eval(context = {})
      expr.eval(Scope.wrap(context))
    end
  end

  class UnaryTestRoot < Node
    def eval(context = {})
      scope = Scope.wrap(context)
      expr.eval(scope).call(scope["?"])
    end
  end

  class AnyUnaryTest < Node
    def eval(_context = {})
      ->(_input) { true }
    end
  end

  class UnaryTestsRoot < Node
    def eval(context = {})
      tests.eval(Scope.wrap(context))
    end
  end

  class NegatedUnaryTests < Node
    def eval(context = {})
      test = tests.eval(Scope.wrap(context))
      ->(input) {
        result = test.call(input)
        result.nil? ? nil : !result
      }
    end
  end

  #
  # 16. positive unary tests = positive unary test , { "," , positive unary test } ;
  #
  class PositiveUnaryTests < Node
    def eval(context = {})
      tests = ([head] + tail.elements.map(&:positive_unary_test)).map { |test| test.eval(context) }
      ->(input) { any_true(tests.map { |test| test.call(input) }) }
    end
  end

  #
  # 15. positive unary test = expression ;
  #
  # The expression is evaluated and compared with the input value:
  # - if the expression contains the input placeholder `?`, it is evaluated with
  #   the input value and the boolean result is the test result
  # - if it evaluates to true, the test passes
  # - if it evaluates to a list, the test passes if the list contains the input
  # - otherwise, the test passes if the value is equal to the input
  #
  class ExpressionUnaryTest < Node
    def eval(context = {})
      if expr.contains_input_placeholder?
        ->(input) {
          result = expr.eval(context.merge("?" => input))
          result == true || result == false ? result : nil
        }
      elsif expr.is_a?(BooleanLiteral)
        value = expr.eval(context)
        ->(input) { feel_equal_or_nil(input, value) }
      else
        value = expr.eval(context)
        ->(input) { unary_match(input, value) }
      end
    end
  end

  #
  # 7. simple positive unary test =
  # 7.a [ "<" | "<=" | ">" | ">=" ] , endpoint |
  # 7.b interval ;
  #
  class UnaryComparison < Node
    def eval(context = {})
      operator_text = operator.text_value
      endpoint_value = endpoint.eval(context)
      ->(input) { feel_compare(operator_text, input, endpoint_value) }
    end
  end

  #
  # 8. interval = ( open interval start | closed interval start ) , endpoint , ".." , endpoint , ( open interval end | closed interval end ) ;
  #
  class Interval < Node
    def eval(context = {})
      low_value = low.eval(context)
      high_value = high.eval(context)
      low_operator = start_token.text_value == "[" ? ">=" : ">"
      high_operator = end_token.text_value == "]" ? "<=" : "<"

      ->(input) {
        lower = feel_compare(low_operator, input, low_value)
        upper = feel_compare(high_operator, input, high_value)
        return nil if lower.nil? || upper.nil?

        lower && upper
      }
    end
  end

  #
  # 57. function definition = "function" , "(" , [ formal parameter { "," , formal parameter } ] , ")" , [ "external" ] , expression ;
  #
  class FunctionDefinition < Node
    def eval(context = {})
      Function.new(params: parameter_names, body: body, closure: context)
    end

    def parameter_names
      formal_parameters.empty? ? [] : formal_parameters.names
    end
  end

  class FormalParameterList < Node
    def names
      ([head] + tail.elements.map(&:formal_parameter)).map(&:parameter_name).map(&:eval)
    end
  end

  #
  # 58. formal parameter = parameter name ;
  #
  class FormalParameter < Node
  end

  #
  # 46. for expression = "for" , name , "in" , expression { "," , name , "in" , expression } , "return" , expression ;
  #
  class ForExpression < Node
    def eval(context = {})
      results = []
      iterate(iteration_contexts, context, results) ? results : nil
    end

    def iteration_contexts
      [head] + tail.elements.map(&:iteration_context)
    end

    def local_names
      iteration_contexts.map { |ctx| ctx.variable.eval } + ["partial"]
    end

    private

    def iterate(contexts, context, results)
      if contexts.empty?
        results << body.eval(context.merge("partial" => results))
        return true
      end

      current, *rest = contexts
      items = current.domain.eval(context)
      return false unless items.is_a?(Array)

      variable_name = current.variable.eval
      items.each do |item|
        return false unless iterate(rest, context.merge(variable_name => item), results)
      end
      true
    end
  end

  class IterationContext < Node
  end

  class RangeExpression < Node
    def eval(context = {})
      low_value = low.eval(context)
      high_value = high.eval(context)
      return nil unless low_value.is_a?(Integer) && high_value.is_a?(Integer)

      low_value <= high_value ? (low_value..high_value).to_a : low_value.downto(high_value).to_a
    end
  end

  #
  # 47. if expression = "if" , expression , "then" , expression , "else" expression ;
  #
  class IfExpression < Node
    def eval(context = {})
      if condition.eval(context) == true
        true_case.eval(context)
      else
        false_case.eval(context)
      end
    end
  end

  #
  # 48. quantified expression = ("some" | "every") , name , "in" , expression , { name , "in" , expression } , "satisfies" , expression ;
  #
  class QuantifiedExpression < Node
    def eval(context = {})
      @some = quantifier.text_value == "some"
      result = iterate(iteration_contexts, context)
      return nil if result == :invalid

      result
    end

    def iteration_contexts
      [head] + tail.elements.map(&:iteration_context)
    end

    def local_names
      iteration_contexts.map { |ctx| ctx.variable.eval }
    end

    private

    # Returns true/false/nil, or :invalid if an iteration domain is not a list.
    def iterate(contexts, context)
      return condition.eval(context) if contexts.empty?

      current, *rest = contexts
      items = current.domain.eval(context)
      return :invalid unless items.is_a?(Array)

      variable_name = current.variable.eval
      decisive = @some ? true : false
      undecided = false
      items.each do |item|
        result = iterate(rest, context.merge(variable_name => item))
        return result if result == :invalid || result == decisive
        undecided = true unless result == !decisive
      end
      undecided ? nil : !decisive
    end
  end

  #
  # 49. disjunction = expression , "or" , expression ;
  #
  class Disjunction < Node
    def eval(context = {})
      undecided = false
      operands.each do |operand|
        value = operand.eval(context)
        return true if value == true
        undecided = true unless value == false
      end
      undecided ? nil : false
    end

    def operands
      [head] + tail.elements.map(&:operand)
    end
  end

  #
  # 50. conjunction = expression , "and" , expression ;
  #
  class Conjunction < Node
    def eval(context = {})
      undecided = false
      operands.each do |operand|
        value = operand.eval(context)
        return false if value == false
        undecided = true unless value == true
      end
      undecided ? nil : true
    end

    def operands
      [head] + tail.elements.map(&:operand)
    end
  end

  #
  # 51. comparison =
  # 51.a expression , ( "=" | "!=" | "<" | "<=" | ">" | ">=" ) , expression |
  #
  class Comparison < Node
    def eval(context = {})
      left_val = left.eval(context)
      right_val = right.eval(context)
      case operator.text_value
      when "<", "<=", ">=", ">" then feel_compare(operator.text_value, left_val, right_val)
      when "!=" then !feel_equal(left_val, right_val)
      when "=" then feel_equal(left_val, right_val)
      end
    end
  end

  #
  # 51.b expression , "between" , expression , "and" , expression |
  #
  class Between < Node
    def eval(context = {})
      input = value.eval(context)
      lower = feel_compare(">=", input, low.eval(context))
      upper = feel_compare("<=", input, high.eval(context))
      return nil if lower.nil? || upper.nil?

      lower && upper
    end
  end

  #
  # 51.c expression , "in" , positive unary test ;
  # 51.d expression , "in" , " (", positive unary tests, ")" ;
  #
  class InExpression < Node
    def eval(context = {})
      tests.eval(context).call(value.eval(context))
    end
  end

  #
  # 53. instance of = expression , "instance" , "of" , type ;
  #
  class InstanceOf < Node
    def eval(context = {})
      instance_of?(value.eval(context), type.text_value.gsub(/\s+/, " "))
    end
  end

  #
  # 21. addition = expression , "+" , expression ;
  # 22. subtraction = expression , "-" , expression ;
  #
  class Addition < Node
    include Arithmetic

    def eval(context = {})
      tail.elements.inject(head.eval(context)) do |result, element|
        operand = element.operand.eval(context)
        element.operator.text_value == "+" ? add(result, operand) : subtract(result, operand)
      end
    end
  end

  #
  # 23. multiplication = expression , "*" , expression ;
  # 24. division = expression , "/" , expression ;
  #
  class Multiplication < Node
    include Arithmetic

    def eval(context = {})
      tail.elements.inject(head.eval(context)) do |result, element|
        operand = element.operand.eval(context)
        element.operator.text_value == "*" ? multiply(result, operand) : divide(result, operand)
      end
    end
  end

  #
  # 25. exponentiation = expression, "**", expression ;
  #
  class Exponentiation < Node
    def eval(context = {})
      head_val = head.eval(context)
      tail_val = tail.eval(context)
      return nil unless head_val.is_a?(Numeric) && tail_val.is_a?(Numeric)

      head_val ** tail_val
    end
  end

  #
  # 26. arithmetic negation = "-" , expression ;
  #
  class ArithmeticNegation < Node
    def eval(context = {})
      value = operand.eval(context)
      return nil unless value.is_a?(Numeric) || value.is_a?(ActiveSupport::Duration)

      -value
    end
  end

  #
  # Path (45), filter (52) and function invocation (40) applied to an expression.
  #
  class PostfixExpression < Node
    def eval(context = {})
      tail.elements.inject(head.eval(context)) do |value, operation|
        operation.apply(value, context)
      end
    end
  end

  #
  # 45. path expression = expression , "." , name ;
  #
  class PathOperation < Node
    def apply(value, context)
      path_get(value, property.respond_to?(:eval) ? property.eval(context) : property.text_value)
    end
  end

  #
  # 52. filter expression = expression , "[" , expression , "]" ;
  #
  class FilterOperation < Node
    def apply(list, context)
      return nil unless list.is_a?(Array)
      return [] if list.empty?

      first = evaluate_for(list.first, context)
      return item_at(list, first) if first.is_a?(Numeric)

      list.each_with_index.select do |item, index|
        (index.zero? ? first : evaluate_for(item, context)) == true
      end.map(&:first)
    end

    def local_names
      ["item"]
    end

    private

    def evaluate_for(item, context)
      locals = item.is_a?(Hash) ? item.to_h.transform_keys(&:to_s) : {}
      filter_expression.eval(context.merge(locals.merge("item" => item)))
    end

    def item_at(list, index)
      index = index.to_i
      return nil if index.zero?

      position = index.positive? ? index - 1 : list.length + index
      position.negative? ? nil : list[position]
    end
  end

  #
  # Invocation of a function value, e.g. `(function(x) x + 1)(2)`.
  #
  class InvocationOperation < Node
    def apply(fn, context)
      return nil unless fn.respond_to?(:call)

      invoke_function(fn, params, context)
    end
  end

  class Parenthesized < Node
    def eval(context = {})
      expr.eval(context)
    end
  end

  #
  # The input value `?` of a unary test.
  #
  class InputValue < Node
    def eval(context = {})
      context["?"]
    end
  end

  #
  # 40. function invocation = expression , parameters ;
  #
  class FunctionInvocation < Node
    def eval(context = {})
      fn = lookup_function(context)

      unless fn.respond_to?(:call)
        raise_evaluation_error(function_name, context) if FEEL.config.strict
        return nil
      end

      args_count = params.empty? ? 0 : params.size
      unless params.is_a?(NamedParameters) || arity_matches?(fn, args_count)
        return function_not_found(function_name, args_count, context)
      end

      invoke_function(fn, params, context)
    end

    def function_name
      fn_name.text_value.gsub(/\s+/, " ")
    end

    private

    def lookup_function(context)
      name = function_name
      return context[name] if context.key?(name)
      return context[name.to_sym] if context.key?(name.to_sym)
      return nil unless fn_name.is_a?(QualifiedName) && !fn_name.tail.empty?

      fn_name.resolve(context, strict: false)
    end
  end

  #
  # 42. named parameters = parameter name , ":" , expression , { "," , parameter name , ":" , expression } ;
  #
  class NamedParameters < Node
    def eval(context = {})
      parameters.each_with_object({}) do |parameter, hash|
        hash[parameter.parameter_name.eval] = parameter.value.eval(context)
      end
    end

    def parameters
      [head] + tail.elements.map(&:named_parameter)
    end

    def size
      parameters.size
    end
  end

  class NamedParameter < Node
  end

  #
  # 44. positional parameters = [ expression , { "," , expression } ] ;
  #
  class PositionalParameters < Node
    def eval(context = {})
      expressions.map { |exp| exp.eval(context) }
    end

    def expressions
      [head] + tail.elements.map(&:expression)
    end

    def size
      expressions.size
    end
  end

  #
  # 20. qualified name = name , { "." , name } ;
  #
  class QualifiedName < Node
    def eval(context = {})
      resolve(context, strict: FEEL.config.strict)
    end

    def resolve(context, strict:)
      value = context_get(context, head.eval(context), strict: strict, root: context)

      tail.elements.each do |element|
        return nil if value.nil?

        key = element.name.eval(context)
        value = if value.respond_to?(:key?)
          context_get(value, key, strict: strict, root: context)
        else
          path_get(value, key)
        end
      end

      value
    end

    private

    # Get a key from the context, using symbol/string lookup, with errors if
    # need be, using the root object for the full path during errors.
    def context_get(context, key, strict:, root:)
      if context.key?(key.to_sym)
        context[key.to_sym]
      elsif context.key?(key)
        context[key]
      else
        raise_evaluation_error(text_value.gsub(/\s+/, ""), root) if strict
        nil
      end
    end
  end

  #
  # 27. name = name start , { name part | additional name symbols } ;
  #
  class Name < Node
    def eval(_context = {})
      text_value.strip.gsub(/\s+/, " ")
    end
  end

  class BacktickName < Node
    def eval(_context = {})
      content.text_value
    end
  end

  #
  # 35. string literal = '"' , { character - ('"' | vertical space) }, '"' ;
  #
  class StringLiteral < Node
    def eval(_context = {})
      chars.elements.map do |char|
        text = char.text_value
        text.start_with?("\\") ? process_escape_sequence(text) : text
      end.join
    end

    private

    def process_escape_sequence(escape_seq)
      case escape_seq
      when "\\n" then "\n"
      when "\\r" then "\r"
      when "\\t" then "\t"
      when '\\"' then '"'
      when "\\'" then "'"
      when "\\\\" then "\\"
      when /\A\\[uU]([0-9a-fA-F]+)\z/ then [Regexp.last_match(1).hex].pack("U")
      else escape_seq[1..]
      end
    end
  end

  #
  # 36. Boolean literal = "true" | "false" ;
  #
  class BooleanLiteral < Node
    def eval(_context = {})
      text_value == "true"
    end
  end

  #
  # 37. numeric literal = [ "-" ] , ( digits , [ ".", digits ] | "." , digits ) ;
  #
  class NumericLiteral < Node
    def eval(_context = {})
      if text_value.include?(".")
        text_value.to_f
      else
        text_value.to_i
      end
    end
  end

  class NullLiteral < Node
    def eval(_context = {})
      nil
    end
  end

  class AtLiteral < Node
    def eval(_context = {})
      Temporal.parse_literal(string_literal.eval)
    end
  end

  #
  # 56. list = "[" [ expression , { "," , expression } ] , "]" ;
  #
  class List < Node
    def eval(context = {})
      expressions.map { |exp| exp.eval(context) }
    end

    def expressions
      return [] unless respond_to?(:head)

      [head] + tail.elements.map(&:expression)
    end
  end

  #
  # 59. context = "{" , [context entry , { "," , context entry } ] , "}" ;
  #
  # Entries can reference previous entries of the same context.
  #
  class ContextLiteral < Node
    def eval(context = {})
      return {} unless respond_to?(:head)

      result = {}
      scope = Scope.new(context, {})
      entries.each do |entry|
        key = entry.key_value
        value = entry.value.eval(scope)
        result[key] = value
        scope.define(key, value) unless key.nil?
      end
      result
    end

    def entries
      [head] + tail.elements.map(&:context_entry)
    end
  end

  #
  # 60. context entry = key , ":" , expression ;
  #
  class ContextEntry < Node
    def key_value
      key.eval
    end
  end

  #
  # 61. key = name | string literal ;
  #
  class ContextKey < Node
    def eval(_context = {})
      name = text_value.gsub(/[[:space:]\u0085\u180E\u200B\uFEFF]+/, " ").strip
      name == "null" ? nil : name
    end
  end
end
