# frozen_string_literal: true

module FEEL
  class Configuration
    DEFAULT_EXPRESSION_CACHE_SIZE = 1_000

    # Custom functions by name (String or Symbol keys), e.g.
    # `{ "reverse" => ->(s) { s.reverse } }`.
    attr_accessor :functions

    # Raise FEEL::EvaluationError for unknown names instead of returning null.
    attr_accessor :strict

    # The zone id (e.g. "Europe/Berlin") of `now()` and `today()`. Default:
    # nil, i.e. `Time.zone` of ActiveSupport if the application uses it, else
    # the system zone.
    attr_accessor :time_zone

    attr_reader :expression_cache_size

    def initialize
      @functions = {}
      @strict = false
      @time_zone = nil
      @expression_cache_size = DEFAULT_EXPRESSION_CACHE_SIZE
    end

    # Maximum number of compiled expressions kept by FEEL.compile (and so by
    # FEEL.evaluate / FEEL.test). 0 or nil disables the cache.
    def expression_cache_size=(size)
      @expression_cache_size = size
      FEEL.expression_cache.max_size = size
      FEEL.unary_tests_cache.max_size = size
    end
  end
end
