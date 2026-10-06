# frozen_string_literal: true

module FEEL
  #
  # A lightweight, hash-like evaluation context. Local variables (e.g. the
  # iteration variables of a for expression or the parameters of a function)
  # are layered on top of a parent context without copying it.
  #
  class Scope
    include Enumerable

    # Returned by `lookup` when no variable has the name.
    MISSING = Object.new.freeze

    def self.wrap(context)
      context.is_a?(Scope) ? context : new(context || {}, {})
    end

    # Looks up a name in a Hash with String or Symbol keys.
    def self.hash_lookup(hash, name, symbol = name.to_sym)
      if hash.key?(name)
        hash[name]
      elsif hash.key?(symbol)
        hash[symbol]
      else
        MISSING
      end
    end

    def initialize(parent, locals = {})
      @parent = parent
      @locals = locals
    end

    def key?(key)
      @locals.key?(key.to_s) || @parent.key?(key)
    end
    alias_method :has_key?, :key?
    alias_method :include?, :key?

    def [](key)
      name = key.to_s
      @locals.key?(name) ? @locals[name] : @parent[key]
    end

    def merge(hash)
      Scope.new(self, hash.to_h.transform_keys(&:to_s))
    end

    # The value of a variable, or MISSING. `name` is a String, `symbol` the
    # same name as Symbol.
    def lookup(name, symbol = name.to_sym)
      return @locals[name] if @locals.key?(name)

      @parent.is_a?(Scope) ? @parent.lookup(name, symbol) : Scope.hash_lookup(@parent, name, symbol)
    end

    def define(key, value)
      @locals[key.to_s] = value
    end

    def to_h
      @parent.to_h.merge(@locals)
    end

    def each(&block)
      to_h.each(&block)
    end
  end

  #
  # A read-only layer over a Hash given by the caller (variables or custom
  # functions) whose keys may be Strings or Symbols. Lookups fall back to the
  # parent layer. The Hash is not copied, so building it is free.
  #
  class HashScope < Scope
    def initialize(hash, parent)
      super(parent)
      @hash = hash
    end

    def key?(key)
      local_key?(key) || @parent.key?(key)
    end
    alias_method :has_key?, :key?
    alias_method :include?, :key?

    def [](key)
      if @hash.key?(key)
        @hash[key]
      elsif key.is_a?(Symbol)
        @hash.key?(name = key.name) ? @hash[name] : @parent[key]
      elsif @hash.key?(symbol = key.to_sym)
        @hash[symbol]
      else
        @parent[key]
      end
    end

    def lookup(name, symbol = name.to_sym)
      value = Scope.hash_lookup(@hash, name, symbol)
      return value unless MISSING.equal?(value)

      @parent.is_a?(Scope) ? @parent.lookup(name, symbol) : Scope.hash_lookup(@parent, name, symbol)
    end

    def define(_key, _value)
      raise FrozenError, "can't modify the root scope"
    end

    def to_h
      @parent.to_h.merge(@hash.to_h.transform_keys(&:to_s))
    end

    private

    def local_key?(key)
      @hash.key?(key) || (key.is_a?(Symbol) ? @hash.key?(key.name) : @hash.key?(key.to_sym))
    end
  end

  #
  # The root scope of an evaluation: the variables, then the custom functions
  # of the configuration, then the built-in functions. Nothing is merged or
  # copied, which keeps evaluating small expressions cheap.
  #
  module RootScope
    module_function

    def build(variables)
      return variables if variables.is_a?(Scope)

      builtins = LiteralExpression.builtin_functions
      custom = FEEL.config.functions
      functions = custom.nil? || custom.empty? ? builtins : HashScope.new(custom, builtins)
      variables.nil? || variables.empty? ? Scope.wrap(functions) : HashScope.new(variables, functions)
    end
  end
end
