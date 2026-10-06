# frozen_string_literal: true

module FEEL
  #
  # A function defined in FEEL, e.g. `function(x, y) x + y`. It can be invoked
  # from FEEL expressions or from Ruby with `call`.
  #
  class Function
    attr_reader :params, :body, :closure

    def initialize(params:, body:, closure:)
      @params = params
      @body = body
      @closure = closure
    end

    def call(*args)
      bindings = params.each_with_index.to_h { |param, index| [param, args[index]] }
      body.eval(Scope.wrap(closure).merge(bindings))
    end

    # Invokes the function with named arguments. Missing arguments are null.
    # Returns nil if an argument doesn't match a parameter.
    def call_named(named_args)
      named_args = named_args.transform_keys { |key| key.to_s.gsub(/\s+/, " ") }
      return nil unless (named_args.keys - params).empty?

      call(*params.map { |param| named_args[param] })
    end

    def arity
      params.length
    end

    def lambda?
      true
    end

    def parameters
      params.map { |param| [:req, param.to_sym] }
    end

    def to_proc
      method(:call).to_proc
    end

    def inspect
      "#<FEEL::Function(#{params.join(", ")})>"
    end
  end
end
