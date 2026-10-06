# frozen_string_literal: true

module FEEL
  #
  # A lightweight, hash-like evaluation context. Local variables (e.g. the
  # iteration variables of a for expression or the parameters of a function)
  # are layered on top of a parent context without copying it.
  #
  class Scope
    include Enumerable

    def self.wrap(context)
      context.is_a?(Scope) ? context : new(context || {}, {})
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
end
