# frozen_string_literal: true

module FEEL
  module AST
    # Builds the text of an expression or unary tests from an AST (see
    # FEEL.unparse). Parentheses are added where the precedence of the
    # operators requires them, names are escaped with backticks if need be.
    class Unparser
      # Precedence levels, from the lowest. A node is put in parentheses
      # if its level is lower than the one required by its position.
      EXPRESSION = 0 # if, for, some/every, function definition
      DISJUNCTION = 1
      CONJUNCTION = 2
      COMPARISON = 3
      ADDITIVE = 4
      MULTIPLICATIVE = 5
      EXPONENTIATION = 6
      NEGATION = 7
      POSTFIX = 8
      PRIMARY = 9

      ARITHMETIC_LEVELS = { "+" => ADDITIVE, "-" => ADDITIVE, "*" => MULTIPLICATIVE, "/" => MULTIPLICATIVE, "**" => EXPONENTIATION }.freeze
      COMPARISON_OPERATORS = %w[= != < <= > >=].freeze
      UNARY_OPERATORS = %w[< <= > >=].freeze
      PROPERTY_NAMES = ["time offset", "start included", "end included"].freeze
      STRING_ESCAPES = { '"' => '\\"', "\\" => "\\\\", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t", "\b" => "\\b", "\f" => "\\f" }.freeze

      def unparse(node)
        case type(node)
        when "unary tests" then tests_text(list(node, :tests), negated: false)
        when "not" then "not(#{tests_text(list(node, :tests), negated: true)})"
        when "any" then "-"
        else test(node)
        end
      end

      private

      #
      # Positions
      #

      # An expression, in parentheses if its level is lower than `level`.
      def expression(node, level = EXPRESSION)
        text, node_level = expression_with_level(node)
        node_level < level ? "(#{text})" : text
      end

      # A positive unary test: a unary comparison, an interval or an
      # expression.
      def test(node)
        case type(node)
        when "unary comparison" then unary_comparison(node)
        when "range" then interval(node)
        else expression(node)
        end
      end

      # A function argument: a range or an expression.
      def argument(node)
        return expression(node) unless type(node) == "range"

        low = fetch(node, :start, required: false)
        high = fetch(node, :end, required: false)
        return interval(node) unless low.nil? || high.nil?
        raise invalid(node, "a range needs a start or an end") if low.nil? && high.nil?

        if low.nil?
          "#{flag(node, :end_included) ? "<=" : "<"} #{expression(high, ADDITIVE)}"
        else
          "#{flag(node, :start_included) ? ">=" : ">"} #{expression(low, ADDITIVE)}"
        end
      end

      # The domain of an iteration: an integer range (`1..10`) or an
      # expression.
      def domain(node)
        return expression(node, DISJUNCTION) unless type(node) == "range"

        low = fetch(node, :start, required: false)
        high = fetch(node, :end, required: false)
        unless low && high && flag(node, :start_included) && flag(node, :end_included)
          raise invalid(node, "the range of an iteration must be closed, e.g. 1..10")
        end

        "#{expression(low, ADDITIVE)}..#{expression(high, ADDITIVE)}"
      end

      def tests_text(tests, negated:)
        raise FEEL::AST::Error, "Unary tests need at least one test" if tests.empty?

        texts = tests.map { |item| test(item) }
        # a call of a function `not` must not read as negated tests
        texts[0] = "(#{texts[0]})" if !negated && texts[0].match?(/\Anot\s*\(/)
        texts.join(", ")
      end

      #
      # Nodes
      #

      def expression_with_level(node)
        case type(node)
        when "number" then number(node)
        when "string" then [string_literal(fetch(node, :value, String)), PRIMARY]
        when "boolean" then [boolean(node), PRIMARY]
        when "null" then ["null", PRIMARY]
        when "temporal" then [temporal(node), PRIMARY]
        when "name" then [path(node), PRIMARY]
        when "input" then ["?", PRIMARY]
        when "list" then ["[#{list(node, :items).map { |item| expression(item) }.join(", ")}]", PRIMARY]
        when "context" then [context(node), PRIMARY]
        when "function call" then ["#{function_name(fetch(node, :name, String))}(#{arguments(node)})", PRIMARY]
        when "path" then ["#{postfix_head(fetch(node, :value))}.#{property_name(fetch(node, :property, String))}", POSTFIX]
        when "filter" then ["#{postfix_head(fetch(node, :value), name: false)}[#{expression(fetch(node, :filter))}]", POSTFIX]
        when "invocation" then ["#{postfix_head(fetch(node, :function))}(#{arguments(node)})", POSTFIX]
        when "negation" then ["-#{expression(fetch(node, :value), NEGATION)}", NEGATION]
        when "arithmetic" then arithmetic(node)
        when "comparison" then [comparison(node), COMPARISON]
        when "between"
          text = "#{expression(fetch(node, :value), ADDITIVE)} between #{expression(fetch(node, :low), ADDITIVE)} and #{expression(fetch(node, :high), ADDITIVE)}"
          [text, COMPARISON]
        when "in"
          tests = list(node, :tests)
          raise invalid(node, "an in expression needs at least one test") if tests.empty?

          ["#{expression(fetch(node, :value), ADDITIVE)} in (#{tests.map { |item| test(item) }.join(", ")})", COMPARISON]
        when "instance of" then ["#{expression(fetch(node, :value), ADDITIVE)} instance of #{type_name(node)}", COMPARISON]
        when "conjunction" then [operands(node, " and ", COMPARISON), CONJUNCTION]
        when "disjunction" then [operands(node, " or ", CONJUNCTION), DISJUNCTION]
        when "if"
          text = "if #{expression(fetch(node, :condition), DISJUNCTION)} then #{expression(fetch(node, :then))} else #{expression(fetch(node, :else))}"
          [text, EXPRESSION]
        when "for" then ["for #{iterations(node)} return #{expression(fetch(node, :return))}", EXPRESSION]
        when "some", "every" then ["#{type(node)} #{iterations(node)} satisfies #{expression(fetch(node, :satisfies))}", EXPRESSION]
        when "function definition" then [function_definition(node), EXPRESSION]
        when "unary comparison", "range", "unary tests", "not", "any"
          raise invalid(node, "not allowed as an expression here")
        else raise invalid(node, "unknown type")
        end
      end

      def number(node)
        value = fetch(node, :value)
        raise invalid(node, "the value must be a number") unless Numbers.number?(value)

        decimal = Numbers.decimal(value)
        raise invalid(node, "the value must be finite") if decimal.nil?

        text = Builtins::ConversionFormat.format_number(decimal.abs)
        decimal.negative? ? ["-#{text}", NEGATION] : [text, PRIMARY]
      end

      def boolean(node)
        value = fetch(node, :value)
        raise invalid(node, "the value must be true or false") unless value == true || value == false

        value.to_s
      end

      def temporal(node)
        text = fetch(node, :text, String, required: false)
        if text.nil?
          value = fetch(node, :value)
          raise invalid(node, "a text or a temporal value is required") unless Temporal.temporal?(value)

          text = Temporal.format_value(value)
        end
        "@#{string_literal(text)}"
      end

      def arithmetic(node)
        operator = fetch(node, :operator, String)
        level = ARITHMETIC_LEVELS[operator] or raise invalid(node, "unknown operator #{operator.inspect}")

        # left-associative: the right operand needs parentheses at the same level
        ["#{expression(fetch(node, :left), level)} #{operator} #{expression(fetch(node, :right), level + 1)}", level]
      end

      def comparison(node)
        operator = fetch(node, :operator, String)
        raise invalid(node, "unknown operator #{operator.inspect}") unless COMPARISON_OPERATORS.include?(operator)

        "#{expression(fetch(node, :left), ADDITIVE)} #{operator} #{expression(fetch(node, :right), ADDITIVE)}"
      end

      def unary_comparison(node)
        operator = fetch(node, :operator, String)
        raise invalid(node, "unknown operator #{operator.inspect}") unless UNARY_OPERATORS.include?(operator)

        "#{operator} #{expression(fetch(node, :value), ADDITIVE)}"
      end

      def interval(node)
        low = fetch(node, :start, required: false)
        high = fetch(node, :end, required: false)
        if low.nil? || high.nil?
          raise invalid(node, "a range needs a start or an end") if low.nil? && high.nil?

          # an open range is a unary comparison, e.g. `< 10`
          return argument(node)
        end

        start_token = flag(node, :start_included) ? "[" : "("
        end_token = flag(node, :end_included) ? "]" : ")"
        "#{start_token}#{expression(low, ADDITIVE)}..#{expression(high, ADDITIVE)}#{end_token}"
      end

      def operands(node, separator, level)
        items = list(node, :operands)
        raise invalid(node, "at least two operands are required") if items.length < 2

        items.map { |item| expression(item, level) }.join(separator)
      end

      def type_name(node)
        name = fetch(node, :of, String)
        raise invalid(node, "invalid type #{name.inspect}") unless parses?(name, :type_name)

        name
      end

      def iterations(node)
        items = list(node, :iterations)
        raise invalid(node, "at least one iteration is required") if items.empty?

        items.map { |item| "#{name(fetch(item, :name, String))} in #{domain(fetch(item, :in))}" }.join(", ")
      end

      def function_definition(node)
        parameters = list(node, :parameters).map do |parameter|
          type = fetch(parameter, :type, String, required: false)
          raise invalid(node, "invalid type #{type.inspect}") if type && !parses?(type, :type_name)

          [parameter_name(fetch(parameter, :name, String)), type].compact.join(": ")
        end
        "function(#{parameters.join(", ")}) #{expression(fetch(node, :body))}"
      end

      def context(node)
        entries = list(node, :entries).map do |entry|
          "#{context_key(fetch(entry, :key, String, required: false))}: #{expression(fetch(entry, :value))}"
        end
        "{#{entries.join(", ")}}"
      end

      def arguments(node)
        named = fetch(node, :named_arguments, Array, required: false)
        if named
          named.map { |entry| "#{parameter_name(fetch(entry, :name, String))}: #{argument(fetch(entry, :value))}" }.join(", ")
        else
          list(node, :arguments).map { |item| argument(item) }.join(", ")
        end
      end

      # The expression to which a path, filter or invocation is applied. A
      # number is put in parentheses, and so is a name for a path or an
      # invocation: `a.b` would be a qualified name and `f(x)` a function call.
      def postfix_head(node, name: true)
        parenthesized = type(node) == "number" || (name && type(node) == "name")
        parenthesized ? "(#{expression(node)})" : expression(node, POSTFIX)
      end

      #
      # Names and literals
      #

      def path(node)
        names = list(node, :path)
        raise invalid(node, "the path is empty") if names.empty?

        names.each_with_index.map do |part, index|
          raise invalid(node, "the path must contain strings") unless part.is_a?(String)

          index.zero? ? name(part) : property_name(part)
        end.join(".")
      end

      def name(text)
        parses?(text, :identifier) ? text : backtick(text)
      end

      def property_name(text)
        PROPERTY_NAMES.include?(text) ? text : name(text)
      end

      # Parameter names may contain spaces, e.g. `start position`.
      def parameter_name(text)
        parses?(text, :parameter_name) && text == text.gsub(/\s+/, " ") ? text : backtick(text)
      end

      # Function names may contain spaces (`string length`) and dots (`a.b`).
      def function_name(text)
        parses?(text, :function_name) && text == text.gsub(/\s+/, " ") ? text : backtick(text)
      end

      # Context keys are names (with spaces) or strings.
      def context_key(key)
        return "null" if key.nil?

        key.match?(/\A[\p{L}_][\p{L}\p{N}_]*( [\p{L}_][\p{L}\p{N}_]*)*\z/) && key != "null" ? key : string_literal(key)
      end

      def backtick(text)
        normalized = text.gsub(/[[:space:]\u0085᠎​﻿]+/, " ").strip
        if text.include?("`") || text.empty? || normalized != text
          raise FEEL::AST::Error, "The name #{text.inspect} can't be written in FEEL"
        end

        "`#{text}`"
      end

      def string_literal(text)
        escaped = text.gsub(/["\\\n\r\t\b\f]|[\u0000-\u001F]/) do |char|
          STRING_ESCAPES[char] || format("\\u%04x", char.ord)
        end
        "\"#{escaped}\""
      end

      def parses?(text, rule)
        @parses ||= {}
        @parses.fetch([text, rule]) do
          @parses[[text, rule]] = !text.empty? && !Parser.instance.parse(text, root: rule).nil?
        end
      end

      #
      # Node access (symbol or string keys, e.g. for an AST read from JSON)
      #

      def type(node)
        raise FEEL::AST::Error, "Invalid node: #{node.inspect}" unless node.is_a?(Hash)

        fetch(node, :type, String)
      end

      def fetch(node, key, klass = nil, required: true)
        value = node.key?(key) ? node[key] : node[key.to_s]
        if value.nil?
          raise invalid(node, "#{key} is missing") if required

          return nil
        end
        raise invalid(node, "#{key} must be a #{klass.name}") if klass && !value.is_a?(klass)

        value
      end

      def list(node, key)
        fetch(node, key, Array)
      end

      def flag(node, key)
        value = fetch(node, key)
        raise invalid(node, "#{key} must be true or false") unless value == true || value == false

        value
      end

      def invalid(node, message)
        type = node.is_a?(Hash) ? (node[:type] || node["type"]) : nil
        FEEL::AST::Error.new("Invalid #{type || "node"} node (#{message}): #{node.inspect}")
      end
    end
  end
end
