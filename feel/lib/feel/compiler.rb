# frozen_string_literal: true

module FEEL
  #
  # Compilation of the AST into Ruby closures.
  #
  # `node.compiled` returns a lambda taking the evaluation context. The
  # closures of the child nodes are built once and captured, so evaluating a
  # compiled expression doesn't walk the Treetop nodes again. Nodes without a
  # specialized compilation fall back to `eval`, so compiled and interpreted
  # evaluation always give the same results.
  #
  # Unary tests compile into lambdas taking the input value and the context
  # (`node.compiled_test`).
  #
  class Node
    # The compiled closure of the node (built once; the tree is immutable).
    def compiled
      @compiled ||= compile
    end

    def compiled_test
      @compiled_test ||= compile_test
    end

    private

    def compile
      ->(context) { eval(context) }
    end

    def compile_test
      ->(input, context) { matches(input, context) }
    end
  end

  #
  # Entry points
  #

  class Root
    private

    def compile
      expression = expr.compiled
      ->(context) { expression.call(Scope === context ? context : Scope.wrap(context)) }
    end
  end

  class UnaryTestsRoot
    private

    def compile_test
      test = tests.compiled_test
      ->(input, context) { test.call(input, Scope === context ? context : Scope.wrap(context)) }
    end
  end

  class NegatedUnaryTests
    private

    def compile_test
      test = tests.compiled_test
      lambda do |input, context|
        result = test.call(input, Scope === context ? context : Scope.wrap(context))
        result.nil? ? nil : !result
      end
    end
  end

  class AnyUnaryTest
    private

    def compile_test
      ->(_input, _context) { true }
    end
  end

  class PositiveUnaryTests
    private

    def compile_test
      tests = unary_tests.map(&:compiled_test)
      return tests.first if tests.size == 1

      lambda do |input, context|
        undecided = false
        tests.each do |test|
          result = test.call(input, context)
          return true if result == true
          undecided = true unless result == false
        end
        undecided ? nil : false
      end
    end
  end

  class ExpressionUnaryTest
    private

    def compile_test
      expression = expr.compiled

      if expr.contains_input_placeholder?
        lambda do |input, context|
          result = expression.call(context.merge("?" => input))
          result == true || result == false ? result : boolean_expected(result)
        end
      elsif expr.is_a?(BooleanLiteral)
        ->(input, context) { equal_values(input, expression.call(context)) }
      else
        ->(input, context) { range_or_value_match(input, expression.call(context)) }
      end
    end
  end

  class UnaryComparison
    private

    def compile_test
      operator = operator_text
      endpoint_value = endpoint.compiled
      ->(input, context) { compare_values(operator, input, endpoint_value.call(context)) }
    end
  end

  class Interval
    private

    def compile_test
      low_operator = start_token.text_value == "[" ? ">=" : ">"
      high_operator = end_token.text_value == "]" ? "<=" : "<"
      low_value = low.compiled
      high_value = high.compiled

      lambda do |input, context|
        lower = compare_values(low_operator, input, low_value.call(context))
        upper = compare_values(high_operator, input, high_value.call(context))
        return nil if lower.nil? || upper.nil?

        lower && upper
      end
    end
  end

  #
  # Literals: constants are computed once.
  #

  class NumericLiteral
    private

    def compile
      value = eval
      ->(_context) { value }
    end
  end

  class BooleanLiteral
    private

    def compile
      value = eval
      ->(_context) { value }
    end
  end

  class NullLiteral
    private

    def compile
      ->(_context) {}
    end
  end

  class StringLiteral
    private

    def compile
      string = value
      # a copy, so callers may modify the result
      ->(_context) { string.dup }
    end
  end

  class InputValue
    private

    def compile
      ->(context) { context["?"] }
    end
  end

  class Parenthesized
    private

    def compile
      expr.compiled
    end
  end

  #
  # Names
  #

  class QualifiedName
    private

    # Same as `resolve`, with a fast path for nested Hashes.
    def compile
      name = head_name
      symbol = head_symbol
      keys = path_keys

      if keys.empty?
        return lambda do |context|
          value = Scope === context ? context.lookup(name, symbol) : Scope.hash_lookup(context, name, symbol)
          Scope::MISSING.equal?(value) ? unknown_name(:unknown_variable, full_name, context) : value
        end
      end

      lambda do |context|
        value = Scope === context ? context.lookup(name, symbol) : Scope.hash_lookup(context, name, symbol)
        return unknown_name(:unknown_variable, full_name, context) if Scope::MISSING.equal?(value)

        keys.each do |key, key_symbol|
          if Hash === value
            value = Scope.hash_lookup(value, key, key_symbol)
            return unknown_name(:no_context_entry, full_name, context) if Scope::MISSING.equal?(value)
          elsif value.nil?
            return null_path(key)
          elsif Scope === value
            value = value.lookup(key, key_symbol)
            return unknown_name(:no_context_entry, full_name, context) if Scope::MISSING.equal?(value)
          else
            value = path_value(value, key, key_symbol, full_name)
          end
        end
        value
      end
    end
  end

  #
  # Operators
  #

  class Addition
    private

    def compile
      first = head.compiled
      steps = operations.map { |plus, operand| [plus, operand.compiled] }

      if steps.size == 1
        plus, second = steps.first
        if plus
          return lambda do |c|
            left = first.call(c)
            right = second.call(c)
            (result = add(left, right)).nil? ? arithmetic_failure("+", left, right) : result
          end
        end
        return lambda do |c|
          left = first.call(c)
          right = second.call(c)
          (result = subtract(left, right)).nil? ? arithmetic_failure("-", left, right) : result
        end
      end

      lambda do |context|
        result = first.call(context)
        steps.each do |plus, operand|
          value = operand.call(context)
          left = result
          result = plus ? add(left, value) : subtract(left, value)
          return arithmetic_failure(plus ? "+" : "-", left, value) if result.nil?
        end
        result
      end
    end
  end

  class Multiplication
    private

    def compile
      first = head.compiled
      steps = operations.map { |times, operand| [times, operand.compiled] }

      if steps.size == 1
        times, second = steps.first
        operator = times ? "*" : "/"
        return lambda do |c|
          left = first.call(c)
          right = second.call(c)
          result = times ? multiply(left, right) : divide(left, right)
          result.nil? ? arithmetic_failure(operator, left, right) : result
        end
      end

      lambda do |context|
        result = first.call(context)
        steps.each do |times, operand|
          value = operand.call(context)
          left = result
          result = times ? multiply(left, value) : divide(left, value)
          return arithmetic_failure(times ? "*" : "/", left, value) if result.nil?
        end
        result
      end
    end
  end

  class ArithmeticNegation
    private

    def compile
      value = operand.compiled
      lambda do |context|
        number = value.call(context)
        if Numbers.number?(number) then -number
        elsif Temporal.duration?(number) then -Temporal.normalize(number)
        else failure(null_or_mismatch(number)) { "Can't negate #{describe(number)}" }
        end
      end
    end
  end

  class Comparison
    private

    def compile
      left_value = left.compiled
      right_value = right.compiled

      case operator.text_value
      when "=" then ->(c) { equal_values(left_value.call(c), right_value.call(c)) }
      when "!=" then ->(c) { (equal = equal_values(left_value.call(c), right_value.call(c))).nil? ? nil : !equal }
      else
        operator_text = operator.text_value.freeze
        ->(c) { compare_values(operator_text, left_value.call(c), right_value.call(c)) }
      end
    end
  end

  class Between
    private

    def compile
      input_value = value.compiled
      low_value = low.compiled
      high_value = high.compiled

      lambda do |context|
        input = input_value.call(context)
        lower = compare_values(">=", input, low_value.call(context))
        upper = compare_values("<=", input, high_value.call(context))
        lower.nil? || upper.nil? ? nil : lower && upper
      end
    end
  end

  class InExpression
    private

    def compile
      input_value = value.compiled
      test = tests.compiled_test
      ->(context) { test.call(input_value.call(context), context) }
    end
  end

  class Conjunction
    private

    def compile
      compiled_operands = operands.map(&:compiled)
      lambda do |context|
        undecided = false
        compiled_operands.each do |operand|
          value = operand.call(context)
          return false if value == false
          next if value == true

          boolean_expected(value)
          undecided = true
        end
        undecided ? nil : true
      end
    end
  end

  class Disjunction
    private

    def compile
      compiled_operands = operands.map(&:compiled)
      lambda do |context|
        undecided = false
        compiled_operands.each do |operand|
          value = operand.call(context)
          return true if value == true
          next if value == false

          boolean_expected(value)
          undecided = true
        end
        undecided ? nil : false
      end
    end
  end

  class IfExpression
    private

    def compile
      condition_value = condition.compiled
      then_value = true_case.compiled
      else_value = false_case.compiled
      lambda do |context|
        result = condition_value.call(context)
        return then_value.call(context) if result == true

        boolean_expected(result) unless result == false
        else_value.call(context)
      end
    end
  end

  #
  # Lists, paths, filters and function invocations
  #

  class List
    private

    def compile
      items = expressions.map(&:compiled)
      ->(context) { items.map { |item| item.call(context) } }
    end
  end

  class PostfixExpression
    private

    def compile
      base = head.compiled
      steps = operations
      lambda do |context|
        value = base.call(context)
        steps.each { |operation| value = operation.apply(value, context) }
        value
      end
    end
  end

  class FunctionInvocation
    private

    def compile
      return super if params.is_a?(NamedParameters)

      arguments = params.empty? ? [] : params.expressions.map(&:compiled)
      count = arguments.size

      lambda do |context|
        fn = lookup_function(context)

        next unknown_name(:unknown_function, function_name, context) unless fn.respond_to?(:call)
        next function_not_found(function_name, count, context) unless arity_matches?(fn, count)

        case count
        when 0 then call_function(fn)
        when 1 then call_function(fn, arguments[0].call(context))
        when 2 then call_function(fn, arguments[0].call(context), arguments[1].call(context))
        else call_function(fn, *arguments.map { |argument| argument.call(context) })
        end
      end
    end
  end
end
