# frozen_string_literal: true

module FEEL
  module Builtins
    #
    # A built-in function with fixed positional parameters whose parameters
    # can be addressed by several names when invoked with named parameters
    # (e.g. `get value(m: ..., key: ...)` or `get value(context: ..., keys: ...)`).
    #
    class AliasedBuiltin < Function
      def initialize(params, aliases = {}, &implementation)
        super(params: params, body: nil, closure: {})
        @aliases = aliases
        @implementation = implementation
      end

      def call(*args)
        @implementation.call(*args)
      end

      def call_named(named_args)
        bindings = {}
        named_args.each do |key, value|
          name = key.to_s.gsub(/\s+/, " ")
          name = @aliases.fetch(name, name)
          return nil unless params.include?(name) && !bindings.key?(name)

          bindings[name] = value
        end
        call(*params.map { |param| bindings[param] })
      end

      def inspect
        "#<FEEL::Builtins::AliasedBuiltin(#{params.join(", ")})>"
      end
    end

    #
    # Helpers for contexts. Contexts are Hashes with String keys, but contexts
    # passed in as variables may have Symbol keys (or be a
    # HashWithIndifferentAccess / Scope). The functions never mutate their
    # arguments.
    #
    module ContextSupport
      module_function

      def context?(value)
        value.is_a?(Hash) || value.is_a?(Scope)
      end

      # A new plain Hash with String keys (shallow copy).
      def to_context(value)
        value.to_h.each_with_object({}) { |(key, val), hash| hash[key.to_s] = val }
      end

      def entry?(context, key)
        context.key?(key) || context.key?(key.to_sym)
      end

      def fetch(context, key)
        return nil unless context?(context)
        return context[key] if context.key?(key)

        context[key.to_sym] if context.key?(key.to_sym)
      end

      # Normalizes a key or a list of keys into a non-empty list of Strings.
      def key_path(keys)
        keys = [keys] if keys.is_a?(String)
        return nil unless keys.is_a?(Array) && keys.any? && keys.all?(String)

        keys
      end

      def get_path(context, keys)
        keys.inject(context) do |value, key|
          return nil unless context?(value) && entry?(value, key)

          fetch(value, key)
        end
      end

      def put_path(context, keys, value)
        result = to_context(context)
        key, *rest = keys
        result[key] = if rest.empty?
          value
        else
          child = fetch(result, key)
          put_path(context?(child) ? child : {}, rest, value)
        end
        result
      end

      def get_value(context, keys)
        return nil unless context?(context)

        keys = key_path(keys)
        keys && get_path(context, keys)
      end

      def context_put(context, keys, value)
        return nil unless context?(context)

        keys = key_path(keys)
        keys && put_path(context, keys, value)
      end

      def context_merge(contexts)
        contexts = contexts.first if contexts.length == 1 && contexts.first.is_a?(Array)
        return nil if contexts.empty? || !contexts.all? { |context| context?(context) }

        contexts.each_with_object({}) { |context, result| result.merge!(to_context(context)) }
      end

      def get_entries(context)
        return nil unless context?(context)

        context.to_h.map { |key, value| { "key" => key.to_s, "value" => value } }
      end

      def from_entries(entries)
        return nil unless entries.is_a?(Array)

        entries.each_with_object({}) do |entry, result|
          return nil unless context?(entry) && entry?(entry, "key") && entry?(entry, "value")

          key = fetch(entry, "key")
          return nil unless key.is_a?(String)

          result[key] = fetch(entry, "value")
        end
      end
    end

    context_put = AliasedBuiltin.new(%w[context key value], "keys" => "key") do |context, keys, value|
      ContextSupport.context_put(context, keys, value)
    end

    context_merge = ->(*contexts) { ContextSupport.context_merge(contexts) }

    CONTEXT = {
      "get value": AliasedBuiltin.new(%w[context key], "m" => "context", "keys" => "key") do |context, keys|
        ContextSupport.get_value(context, keys)
      end,
      "get entries": AliasedBuiltin.new(%w[context], "m" => "context") do |context|
        ContextSupport.get_entries(context)
      end,
      "context put": context_put,
      "put": context_put, # deprecated
      "context merge": context_merge,
      "put all": context_merge, # deprecated
      "context": ->(entries) { ContextSupport.from_entries(entries) },
    }.freeze
  end
end
