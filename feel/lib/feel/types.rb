# frozen_string_literal: true

module FEEL
  #
  # The types of `instance of`: the basic types (`number`, `string`, `date`,
  # `Any`, `Null`, ...) and the structured types `list<T>`, `range<T>`,
  # `context<name: T, ...>` and `function<T, ...> -> T`.
  #
  module Types
    # A type: its name, the types of a list, range or function (`params`),
    # the entries of a context type (`entries`), the result of a function.
    Type = Struct.new(:name, :params, :entries, :result)

    CACHE = {} # rubocop:disable Style/MutableConstant
    MUTEX = Mutex.new

    module_function

    # The parsed type (cached by text).
    def parse(text)
      MUTEX.synchronize { CACHE[text] ||= Parser.new(text).parse }
    end

    # Whether the value is an instance of the type (text).
    def instance_of?(value, text, values)
      check(value, parse(text), values)
    end

    def check(value, type, values)
      return false if type.nil?

      case type.name
      when "Any" then !value.nil?
      when "Null" then value.nil?
      when "list" then value.is_a?(Array) && (type.params.empty? || value.all? { |item| item.nil? || check(item, type.params.first, values) })
      when "range"
        value.is_a?(FEEL::Range) && (type.params.empty? || check(value.sample, type.params.first, values))
      when "context"
        (value.is_a?(Hash) || value.is_a?(Scope)) && type.entries.all? do |name, entry_type|
          context = value.to_h.transform_keys(&:to_s)
          context.key?(name) && (context[name].nil? || check(context[name], entry_type, values))
        end
      when "function"
        function?(value) && (type.params.nil? || arity(value).nil? || arity(value) == type.params.size)
      else values.feel_instance_of?(value, type.name)
      end
    end

    def function?(value)
      value.is_a?(Function) || value.is_a?(Proc) || value.is_a?(Method)
    end

    def arity(function)
      return function.params.size if function.is_a?(Function)

      function.arity if function.respond_to?(:lambda?) && function.lambda? && function.arity >= 0
    end

    # A parser of the type text.
    class Parser
      def initialize(text)
        @text = text
        @position = 0
      end

      def parse
        type = type()
        skip
        @position == @text.length ? type : nil
      rescue ArgumentError
        nil
      end

      private

      def type
        skip
        name = name()
        case name
        when "list", "range"
          return Type.new(name, []) unless peek("<")

          expect("<")
          param = type
          expect(">")
          Type.new(name, [param])
        when "context"
          return Type.new(name, [], {}) unless peek("<")

          expect("<")
          entries = {}
          loop do
            skip
            key = name()
            expect(":")
            entries[key] = type
            break unless accept(",")
          end
          expect(">")
          Type.new(name, [], entries)
        when "function"
          return Type.new(name) unless peek("<") || peek("->")

          params = nil
          if accept("<")
            params = []
            unless peek(">")
              loop do
                params << type
                break unless accept(",")
              end
            end
            expect(">")
          end
          result = accept("->") ? type : nil
          Type.new(name, params, nil, result)
        else Type.new(name)
        end
      end

      def name
        skip
        match = @text[@position..].match(/\A(date and time|years and months duration|days and time duration|`[^`]+`|[^\s<>,:\-]+)/)
        raise ArgumentError, "type expected" unless match

        @position += match[0].length
        match[0].delete("`")
      end

      def skip
        @position += 1 while @position < @text.length && @text[@position].match?(/\s/)
      end

      def peek(token)
        skip
        @text[@position, token.length] == token
      end

      def accept(token)
        return false unless peek(token)

        @position += token.length
        true
      end

      def expect(token)
        raise ArgumentError, "#{token} expected" unless accept(token)
      end
    end
  end
end
