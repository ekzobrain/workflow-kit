# frozen_string_literal: true

module FEEL
  class Configuration
    DEFAULT_EXPRESSION_CACHE_SIZE = 1_000

    attr_accessor :functions, :strict
    attr_reader :expression_cache_size

    def initialize
      @functions = HashWithIndifferentAccess.new
      @strict = false
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
