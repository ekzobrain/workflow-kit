# frozen_string_literal: true

module FEEL
  class Node < Treetop::Runtime::SyntaxNode
    include Values

    # Whether the subtree uses the input value `?` (memoized: the tree is
    # immutable once parsed).
    def contains_input_placeholder?
      return @contains_input_placeholder if defined?(@contains_input_placeholder)

      @contains_input_placeholder = Node.input_placeholder_in?(self)
    end

    def self.input_placeholder_in?(node)
      return true if node.is_a?(InputValue)
      return false unless node.elements

      node.elements.any? { |element| input_placeholder_in?(element) }
    end

    # Unary test nodes match an input value with `matches(input, context)`.
    # `eval` returns the test as a lambda for callers that need one.
    def test_lambda(context)
      ->(input) { matches(input, context) }
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

    #
    # Diagnostics (see FEEL::Diagnostics): each method records why the node's
    # result is null - raising FEEL::EvaluationError in strict mode - and
    # returns nil.
    #

    # The part of the expression reported for a failure of the node.
    def diagnostic_interval
      interval
    end

    def failure(reason, raise_error: true)
      return nil unless diagnostics?

      Diagnostics.report(self, reason, raise_error: raise_error) { yield }
    end

    # Whether failures are reported (warnings collected or strict mode):
    # checked first, so a lenient evaluation doesn't pay for them.
    def diagnostics?
      Diagnostics.enabled
    end

    def describe(value)
      Diagnostics.describe(value)
    end

    # A name not in scope (`missing_name` is the full path, e.g. "a.b").
    def unknown_name(reason, missing_name, ctx = {})
      return nil unless diagnostics?

      failure(reason, raise_error: !existence_check?) do
        names = qualified_names_in_context(ctx)
        guess = DidYouMean::SpellChecker.new(dictionary: names).correct(missing_name)
        suffix = " Did you mean #{guess.first}?" unless guess.empty?
        "Identifier #{missing_name} not found.#{suffix}"
      end
    end

    # A path (`value.name`) into null.
    def null_path(name)
      return nil unless diagnostics?

      failure(:null_operand) { "Can't get '#{name}' of null" }
    end

    def null_or_mismatch(value)
      value.nil? ? :null_operand : :type_mismatch
    end

    # A value that is not true or false where a boolean is needed.
    def boolean_expected(value)
      return nil unless diagnostics?

      failure(null_or_mismatch(value)) { "Expected a boolean but found #{describe(value)}" }
    end

    # A value that is not a list where a list is needed.
    def list_expected(value)
      return nil unless diagnostics?

      failure(null_or_mismatch(value)) { "Expected a list but found #{describe(value)}" }
    end

    ARITHMETIC_VERBS = { "+" => "add", "-" => "subtract", "*" => "multiply", "/" => "divide", "**" => "raise" }.freeze

    # An arithmetic operation that results in null.
    def arithmetic_failure(operator, left, right)
      return nil unless diagnostics?

      verb = ARITHMETIC_VERBS[operator]
      if left.nil? || right.nil?
        failure(:null_operand) { "Can't #{verb} #{describe(left)} and #{describe(right)}" }
      elsif operator == "/" && zero?(right)
        failure(:division_by_zero) { "Can't divide #{describe(left)} by zero" }
      else
        failure(:type_mismatch) { "Can't #{verb} #{describe(left)} and #{describe(right)}" }
      end
    end

    def zero?(value)
      (Numbers.number?(value) && value.zero?) || (Temporal.duration?(value) && Temporal.normalize(value).zero?)
    rescue NoMethodError
      false
    end

    # A context without an entry for the key, in a path over an expression.
    def missing_entry(name, context)
      return nil unless diagnostics?

      failure(:no_context_entry, raise_error: !existence_check?) do
        keys = context.respond_to?(:keys) ? context.keys.map(&:to_s) : []
        guess = DidYouMean::SpellChecker.new(dictionary: keys).correct(name)
        suffix = " Did you mean #{guess.first}?" unless guess.empty?
        "No context entry found with key '#{name}'.#{suffix}"
      end
    end

    def not_comparable(left, right)
      return nil unless diagnostics?

      reason = left.nil? || right.nil? ? :null_operand : :type_mismatch
      failure(reason) { "Can't compare #{describe(left)} with #{describe(right)}" }
    end

    #
    # Paths
    #

    PROPERTIES = {
      date: %w[year month day weekday],
      time: ["hour", "minute", "second", "time offset", "timezone"],
      date_time: ["year", "month", "day", "weekday", "hour", "minute", "second", "time offset", "timezone"],
      years_months_duration: %w[years months],
      days_time_duration: %w[days hours minutes seconds],
      range: ["start", "end", "start included", "end included"],
    }.freeze

    # The entry of a context with the key, or MISSING.
    def context_entry(context, key, symbol)
      context.is_a?(Scope) ? context.lookup(key, symbol) : Scope.hash_lookup(context, key, symbol)
    end

    # The property of a value (`value.name`), the properties of the items of a
    # list.
    def path_value(value, name, symbol = name.to_sym, full_name = nil)
      if value.nil?
        null_path(name)
      elsif value.is_a?(Hash) || value.is_a?(Scope)
        found = context_entry(value, name, symbol)
        return found unless Scope::MISSING.equal?(found)

        full_name ? unknown_name(:no_context_entry, full_name, value) : missing_entry(name, value)
      elsif value.is_a?(Array)
        value.map { |item| path_value(item, name, symbol, full_name) }
      elsif value.respond_to?(:key?) && !Temporal.temporal?(value)
        found = Scope.hash_lookup(value, name, symbol)
        return found unless Scope::MISSING.equal?(found)

        full_name ? unknown_name(:no_context_entry, full_name, {}) : missing_entry(name, value)
      else
        result = access_property(value, name)
        return result unless result.nil?

        properties = PROPERTIES[value.is_a?(FEEL::Range) ? :range : type_kind(value)]
        return nil if properties&.include?(name)

        failure(:not_a_context) do
          available = properties ? ". Available properties: #{properties.join(", ")}" : ""
          "No property '#{name}' of #{describe(value)}#{available}"
        end
      end
    end

    # Whether the node is only checked for existence, so a missing name or
    # context entry is null rather than an error: `x = null`, `x != null`,
    # `is defined(x)`, `get or else(x, default)`.
    def existence_check?
      return @existence_check if defined?(@existence_check)

      @existence_check = Node.existence_check?(self)
    end

    def self.existence_check?(node)
      child = node
      parent = node.parent
      while parent && (parent.instance_of?(Treetop::Runtime::SyntaxNode) || parent.is_a?(Parenthesized) ||
                       parent.is_a?(QualifiedName) || parent.is_a?(PostfixExpression) || parent.is_a?(PathOperation))
        child = parent
        parent = parent.parent
      end

      case parent
      when Comparison
        return false unless %w[= !=].include?(parent.operator.text_value)

        other = parent.left.equal?(child) ? parent.right : parent.left
        other = other.expr while other.is_a?(Parenthesized)
        other.is_a?(NullLiteral)
      when PositionalParameters
        invocation = parent.parent
        invocation.is_a?(FunctionInvocation) && ["is defined", "get or else"].include?(invocation.function_name) &&
          parent.expressions.first.equal?(child)
      else
        false
      end
    end

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
      return arguments_mismatch(fn, args.length) unless arity_matches?(fn, args.length)

      call_function(fn, *args)
    end

    def invoke_with_named_parameters(fn, named_args)
      if fn.instance_of?(Function)
        names = named_args.keys.map { |key| key.to_s.gsub(/\s+/, " ") }
        return named_arguments_mismatch(fn, names) unless (names - fn.params).empty?
      end
      return fn.call_named(named_args) if fn.is_a?(Function)
      return named_arguments_mismatch(fn, named_args.keys) unless fn.respond_to?(:parameters)

      parameters = fn.parameters
      names = parameters.map { |_type, name| name.to_s }
      keys = named_args.keys.map { |key| key.to_s.tr(" ", "_") }
      return named_arguments_mismatch(fn, named_args.keys) unless (keys - names).empty?

      args = parameters.each_with_index.map do |(_type, name), _index|
        named_args.find { |key, _value| key.to_s.tr(" ", "_") == name.to_s }&.last
      end
      args.pop while args.any? && args.last.nil? && optional_parameter?(parameters[args.length - 1])
      return arguments_mismatch(fn, args.length) unless arity_matches?(fn, args.length)

      call_function(fn, *args)
    end

    def optional_parameter?(parameter)
      parameter && parameter.first == :opt
    end

    def arity_matches?(fn, count)
      return count == fn.params.length if fn.is_a?(Function)
      return true unless fn.respond_to?(:lambda?) && fn.lambda?

      arity = fn.arity
      return count == arity if arity >= 0

      required, maximum = Node.arity_range(fn)
      count >= required && (maximum.nil? || count <= maximum)
    end

    ARITY_RANGES = ObjectSpace::WeakKeyMap.new

    # [required, maximum or nil (varargs)] of a lambda with optional
    # parameters, cached per lambda.
    def self.arity_range(fn)
      ARITY_RANGES[fn] ||= begin
        parameters = fn.parameters
        required = parameters.count { |type, _| type == :req }
        optional = parameters.count { |type, _| type == :opt }
        rest = parameters.any? { |type, _| type == :rest }
        [required, rest ? nil : required + optional].freeze
      end
    end

    # Three-valued equality: null if the values are not comparable (different
    # types, or functions).
    def equal_values(left, right)
      return not_comparable(left, right) if type_kind(left) == :function && type_kind(right) == :function

      result = feel_equal_or_nil(left, right)
      result.nil? ? not_comparable(left, right) : result
    end

    # Ordering comparison: null if the values have different types.
    def compare_values(operator, left, right)
      result = feel_compare(operator, left, right) if type_kind(left) == type_kind(right)
      result.nil? ? not_comparable(left, right) : result
    end

    # Matches an input value with the value of a unary test expression (see
    # Values#unary_match): null if they are not comparable.
    def unary_test_match(input, value)
      result = unary_match(input, value)
      result.nil? ? not_comparable(input, value) : result
    end

    # Invokes a built-in or user function (Ruby proc). A failure of the
    # function results in null.
    def call_function(fn, *args)
      result = fn.call(*args)
      result.nil? ? function_returned_null(fn, args, nil) : result
    rescue EvaluationError => e
      e.expression ||= text_value.strip
      e.position ||= interval
      raise
    rescue StandardError => e
      raise if fn.is_a?(Function)

      function_returned_null(fn, args, e)
    end

    # Why a function call results in null: a null argument, an invalid
    # argument of a built-in function, or an error of a custom function.
    def function_returned_null(fn, args, error)
      name = LiteralExpression.builtin_name(fn)
      return builtin_returned_null(name, args, error) if name
      return nil if fn.is_a?(Function) || error.nil?

      failure(:function_failure) { "Function '#{display_name(fn)}' failed: #{error.message}" }
    end

    def builtin_returned_null(name, args, error)
      return nil if name == "assert" # reports its own failure
      if args.any? { |arg| arg.nil? || (arg.is_a?(Array) && arg.include?(nil)) }
        return failure(:null_operand) { "Function '#{name}' returns null for a null argument" }
      end

      if (validate = Builtins::NULL_RESULTS[name])
        reason, problem = validate.call(*args)
        return nil if reason.nil?

        return failure(reason) { "Function '#{name}' can't be applied to #{args.map { |arg| describe(arg) }.join(", ")}: #{problem}" }
      end

      failure(:invalid_argument) do
        detail = error && !error.message.empty? ? " (#{error.message})" : ""
        "Function '#{name}' can't be applied to #{args.map { |arg| describe(arg) }.join(", ")}#{detail}"
      end
    end

    def display_name(fn)
      respond_to?(:function_name) ? function_name : "function"
    end

    def arguments_mismatch(fn, count)
      failure(:arguments) { "No function found with name '#{display_name(fn)}' and #{count} parameters" }
    end

    def named_arguments_mismatch(fn, names)
      failure(:arguments) { "Function '#{display_name(fn)}' has no parameters named #{names.map(&:to_s).join(", ")}" }
    end

    def function_not_found(name, args_count, _context = nil)
      failure(:arguments) { "No function found with name '#{name}' and #{args_count} parameters" }
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
      expr.matches(scope["?"], scope)
    end
  end

  class AnyUnaryTest < Node
    def eval(context = {})
      test_lambda(context)
    end

    def matches(_input, _context)
      true
    end
  end

  class UnaryTestsRoot < Node
    def eval(context = {})
      test_lambda(Scope.wrap(context))
    end

    def matches(input, context)
      tests.matches(input, Scope.wrap(context))
    end
  end

  class NegatedUnaryTests < Node
    def eval(context = {})
      test_lambda(Scope.wrap(context))
    end

    def matches(input, context)
      result = tests.matches(input, Scope.wrap(context))
      result.nil? ? nil : !result
    end
  end

  #
  # 16. positive unary tests = positive unary test , { "," , positive unary test } ;
  #
  class PositiveUnaryTests < Node
    def eval(context = {})
      test_lambda(context)
    end

    # Three-valued OR: true if a test matches, false if none matches, null otherwise.
    def matches(input, context)
      undecided = false
      unary_tests.each do |test|
        result = test.matches(input, context)
        return true if result == true
        undecided = true unless result == false
      end
      undecided ? nil : false
    end

    def unary_tests
      @unary_tests ||= [head] + tail.elements.map(&:positive_unary_test)
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
      test_lambda(context)
    end

    def matches(input, context)
      if expr.contains_input_placeholder?
        result = expr.eval(context.merge("?" => input))
        result == true || result == false ? result : boolean_expected(result)
      elsif expr.is_a?(BooleanLiteral)
        equal_values(input, expr.eval(context))
      else
        range_or_value_match(input, expr.eval(context))
      end
    end

    def range_or_value_match(input, value)
      return unary_test_match(input, value) unless value.is_a?(FEEL::Range)

      result = value.include?(input)
      result.nil? ? not_comparable(input, value) : result
    end
  end

  #
  # 7. simple positive unary test =
  # 7.a [ "<" | "<=" | ">" | ">=" ] , endpoint |
  # 7.b interval ;
  #
  class UnaryComparison < Node
    def eval(context = {})
      test_lambda(context)
    end

    def matches(input, context)
      compare_values(operator_text, input, endpoint.eval(context))
    end

    def operator_text
      @operator_text ||= operator.text_value.freeze
    end
  end

  #
  # 8. interval = ( open interval start | closed interval start ) , endpoint , ".." , endpoint , ( open interval end | closed interval end ) ;
  #
  class Interval < Node
    def eval(context = {})
      test_lambda(context)
    end

    def matches(input, context)
      @low_operator ||= start_token.text_value == "[" ? ">=" : ">"
      @high_operator ||= end_token.text_value == "]" ? "<=" : "<"
      lower = compare_values(@low_operator, input, low.eval(context))
      upper = compare_values(@high_operator, input, high.eval(context))
      return nil if lower.nil? || upper.nil?

      lower && upper
    end
  end

  #
  # A range value used as a function argument, e.g. `[1..10]` or `(1..10]`.
  #
  class RangeLiteral < Node
    def eval(context = {})
      low_value = low.eval(context)
      high_value = high.eval(context)
      return nil if low_value.nil? || high_value.nil?

      FEEL::Range.build(low_value, high_value, start_token.text_value == "[", end_token.text_value == "]")
    end
  end

  #
  # An open-ended range value used as a function argument, e.g. `< 10`.
  #
  class OpenRangeLiteral < Node
    def eval(context = {})
      value = endpoint.eval(context)
      return nil if value.nil?

      case operator.text_value
      when "<" then FEEL::Range.build(nil, value, false, false)
      when "<=" then FEEL::Range.build(nil, value, false, true)
      when ">" then FEEL::Range.build(value, nil, false, false)
      when ">=" then FEEL::Range.build(value, nil, true, false)
      end
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
      @iteration_contexts ||= [head] + tail.elements.map(&:iteration_context)
    end

    private

    def iterate(contexts, context, results)
      if contexts.empty?
        results << body.eval(context.merge("partial" => results))
        return true
      end

      current, *rest = contexts
      items = current.domain.eval(context)
      return list_expected(items) || false unless items.is_a?(Array)

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
      unless low_value.is_a?(Integer) && high_value.is_a?(Integer)
        reason = low_value.nil? || high_value.nil? ? :null_operand : :type_mismatch
        return failure(reason) { "Expected integers for a range but found #{describe(low_value)} and #{describe(high_value)}" }
      end

      low_value <= high_value ? (low_value..high_value).to_a : low_value.downto(high_value).to_a
    end
  end

  #
  # 47. if expression = "if" , expression , "then" , expression , "else" expression ;
  #
  class IfExpression < Node
    def eval(context = {})
      result = condition.eval(context)
      return true_case.eval(context) if result == true

      boolean_expected(result) unless result == false
      false_case.eval(context)
    end
  end

  #
  # 48. quantified expression = ("some" | "every") , name , "in" , expression , { name , "in" , expression } , "satisfies" , expression ;
  #
  class QuantifiedExpression < Node
    def eval(context = {})
      @some = quantifier.text_value == "some" unless defined?(@some)
      result = iterate(iteration_contexts, context)
      return nil if result == :invalid

      result
    end

    def iteration_contexts
      @iteration_contexts ||= [head] + tail.elements.map(&:iteration_context)
    end

    private

    # Returns true/false/nil, or :invalid if an iteration domain is not a list.
    def iterate(contexts, context)
      if contexts.empty?
        result = condition.eval(context)
        return result == true || result == false ? result : boolean_expected(result)
      end

      current, *rest = contexts
      items = current.domain.eval(context)
      return list_expected(items) || :invalid unless items.is_a?(Array)

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
        next if value == false

        boolean_expected(value)
        undecided = true
      end
      undecided ? nil : false
    end

    def operands
      @operands ||= [head] + tail.elements.map(&:operand)
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
        next if value == true

        boolean_expected(value)
        undecided = true
      end
      undecided ? nil : true
    end

    def operands
      @operands ||= [head] + tail.elements.map(&:operand)
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
      operator_text = (@operator_text ||= operator.text_value.freeze)
      case operator_text
      when "<", "<=", ">=", ">" then compare_values(operator_text, left_val, right_val)
      when "!=" then (equal = equal_values(left_val, right_val)).nil? ? nil : !equal
      when "=" then equal_values(left_val, right_val)
      end
    end
  end

  #
  # 51.b expression , "between" , expression , "and" , expression |
  #
  class Between < Node
    def eval(context = {})
      input = value.eval(context)
      lower = compare_values(">=", input, low.eval(context))
      upper = compare_values("<=", input, high.eval(context))
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
      tests.matches(value.eval(context), context)
    end
  end

  #
  # 53. instance of = expression , "instance" , "of" , type ;
  #
  class InstanceOf < Node
    def eval(context = {})
      feel_instance_of?(value.eval(context), @type_name ||= type.text_value.gsub(/\s+/, " ").freeze)
    end
  end

  #
  # 21. addition = expression , "+" , expression ;
  # 22. subtraction = expression , "-" , expression ;
  #
  class Addition < Node
    include Arithmetic

    def eval(context = {})
      result = head.eval(context)
      operations.each do |plus, operand|
        value = operand.eval(context)
        left = result
        result = plus ? add(left, value) : subtract(left, value)
        return arithmetic_failure(plus ? "+" : "-", left, value) if result.nil?
      end
      result
    end

    # [[plus?, operand node], ...]
    def operations
      @operations ||= tail.elements.map { |element| [element.operator.text_value == "+", element.operand] }
    end
  end

  #
  # 23. multiplication = expression , "*" , expression ;
  # 24. division = expression , "/" , expression ;
  #
  class Multiplication < Node
    include Arithmetic

    def eval(context = {})
      result = head.eval(context)
      operations.each do |times, operand|
        value = operand.eval(context)
        left = result
        result = times ? multiply(left, value) : divide(left, value)
        return arithmetic_failure(times ? "*" : "/", left, value) if result.nil?
      end
      result
    end

    # [[multiply?, operand node], ...]
    def operations
      @operations ||= tail.elements.map { |element| [element.operator.text_value == "*", element.operand] }
    end
  end

  #
  # 25. exponentiation = expression, "**", expression ;
  #
  class Exponentiation < Node
    def eval(context = {})
      tail.elements.inject(head.eval(context)) do |base, element|
        exponent = element.operand.eval(context)
        return arithmetic_failure("**", base, exponent) unless Numbers.number?(base) && Numbers.number?(exponent)

        base**exponent
      end
    end
  end

  #
  # 26. arithmetic negation = "-" , expression ;
  #
  class ArithmeticNegation < Node
    def eval(context = {})
      value = operand.eval(context)
      return -value if Numbers.number?(value)
      return -Temporal.normalize(value) if Temporal.duration?(value)

      failure(null_or_mismatch(value)) { "Can't negate #{describe(value)}" }
    end
  end

  #
  # Path (45), filter (52) and function invocation (40) applied to an expression.
  #
  class PostfixExpression < Node
    def eval(context = {})
      value = head.eval(context)
      operations.each { |operation| value = operation.apply(value, context) }
      value
    end

    def operations
      @operations ||= tail.elements
    end
  end

  # A path, filter or invocation is reported with the expression it applies
  # to, e.g. `a[1].b` rather than `.b`.
  module PostfixOperation
    def diagnostic_interval
      postfix = parent
      postfix = postfix.parent until postfix.nil? || postfix.is_a?(PostfixExpression)
      postfix ? (postfix.interval.begin...interval.end) : interval
    end
  end

  #
  # 45. path expression = expression , "." , name ;
  #
  class PathOperation < Node
    include PostfixOperation

    def apply(value, context)
      path_value(value, @property_name ||= (property.respond_to?(:eval) ? property.eval(context) : property.text_value).freeze)
    end
  end

  #
  # 52. filter expression = expression , "[" , expression , "]" ;
  #
  class FilterOperation < Node
    include PostfixOperation

    def apply(list, context)
      return list_expected(list) unless list.is_a?(Array)
      return [] if list.empty?

      first = evaluate_for(list.first, context)
      return item_at(list, first) if first.is_a?(Numeric)

      list.each_with_index.select do |item, index|
        result = index.zero? ? first : evaluate_for(item, context)
        boolean_expected(result) unless result == true || result == false || result.nil?
        result == true
      end.map(&:first)
    end

    private

    def evaluate_for(item, context)
      locals = item.is_a?(Hash) ? item.to_h.transform_keys(&:to_s) : {}
      filter_expression.compiled.call(context.merge({ "item" => item }.merge(locals)))
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
    include PostfixOperation

    def apply(fn, context)
      return failure(null_or_mismatch(fn)) { "Expected a function but found #{describe(fn)}" } unless fn.respond_to?(:call)

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

      return unknown_name(:unknown_function, function_name, context) unless fn.respond_to?(:call)

      args_count = params_count
      unless params.is_a?(NamedParameters) || arity_matches?(fn, args_count)
        return function_not_found(function_name, args_count, context)
      end

      invoke_function(fn, params, context)
    end

    def function_name
      @function_name ||= fn_name.text_value.gsub(/\s+/, " ").freeze
    end

    private

    def params_count
      @params_count ||= params.empty? ? 0 : params.size
    end

    def lookup_function(context)
      name = function_name
      fn = context[name]
      return fn unless fn.nil?
      return context[name.to_sym] if context.key?(name.to_sym)
      return nil unless fn_name.is_a?(QualifiedName) && !fn_name.tail.empty?

      fn_name.resolve(context, report: false)
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
      @parameters ||= [head] + tail.elements.map(&:named_parameter)
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
      @expressions ||= [head] + tail.elements.map(&:argument)
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
      resolve(context)
    end

    # The value of the name, reporting a missing name or context entry
    # (unless `report` is false).
    def resolve(context, report: true)
      value = context_entry(context, head_name, head_symbol)
      return report ? unknown_name(:unknown_variable, full_name, context) : nil if Scope::MISSING.equal?(value)

      path_keys.each do |key, symbol|
        if value.nil?
          return report ? null_path(key) : nil
        elsif Hash === value || Scope === value
          value = context_entry(value, key, symbol)
          return report ? unknown_name(:no_context_entry, full_name, context) : nil if Scope::MISSING.equal?(value)
        else
          value = report ? path_value(value, key, symbol, full_name) : path_get(value, key)
        end
      end

      value
    end

    def full_name
      @full_name ||= text_value.gsub(/\s+/, "").freeze
    end

    private

    def head_name
      @head_name ||= head.eval.freeze
    end

    def head_symbol
      @head_symbol ||= head_name.to_sym
    end

    # [[name, symbol], ...] of the path after the head name
    def path_keys
      @path_keys ||= tail.elements.map do |element|
        key = (element.name.respond_to?(:eval) ? element.name.eval : element.name.text_value).freeze
        [key, key.to_sym]
      end
    end
  end

  #
  # 27. name = name start , { name part | additional name symbols } ;
  #
  class Name < Node
    def eval(_context = {})
      @name ||= text_value.strip.gsub(/\s+/, " ").freeze
    end
  end

  class BacktickName < Node
    def eval(_context = {})
      @name ||= content.text_value.gsub(/[[:space:]\u0085\u180E\u200B\uFEFF]+/, " ").strip.freeze
    end
  end

  #
  # 35. string literal = '"' , { character - ('"' | vertical space) }, '"' ;
  #
  class StringLiteral < Node
    # Returns a new (unfrozen) copy of the literal so callers may modify it.
    def eval(_context = {})
      value.dup
    end

    def value
      @value ||= chars.elements.map do |char|
        text = char.text_value
        text.start_with?("\\") ? process_escape_sequence(text) : text
      end.join.freeze
    end

    private

    def process_escape_sequence(escape_seq)
      case escape_seq
      when "\\n" then "\n"
      when "\\r" then "\r"
      when "\\t" then "\t"
      when "\\b" then "\b"
      when "\\f" then "\f"
      when '\\"' then '"'
      when "\\'" then "'"
      when "\\\\" then "\\"
      when /\A\\u([0-9a-fA-F]{4})\z/ then [Regexp.last_match(1).hex].pack("U")
      else escape_seq
      end
    end
  end

  #
  # 36. Boolean literal = "true" | "false" ;
  #
  class BooleanLiteral < Node
    def eval(_context = {})
      return @value if defined?(@value)

      @value = text_value == "true"
    end
  end

  #
  # 37. numeric literal = [ "-" ] , ( digits , [ ".", digits ] | "." , digits ) ;
  #
  class NumericLiteral < Node
    # Decimal literals are exact (BigDecimal), integer literals are Integers.
    def eval(_context = {})
      @value ||= text_value.include?(".") ? BigDecimal(text_value) : text_value.to_i
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
    rescue ArgumentError, Date::Error
      nil
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
      @expressions ||= respond_to?(:head) ? [head] + tail.elements.map(&:expression) : []
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
      @entries ||= respond_to?(:head) ? [head] + tail.elements.map(&:context_entry) : []
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
      return @name if defined?(@name)

      name = text_value.gsub(/[[:space:]\u0085\u180E\u200B\uFEFF]+/, " ").strip.freeze
      @name = name == "null" ? nil : name
    end
  end
end
