# frozen_string_literal: true

module FEEL
  #
  # A thread-safe LRU cache of compiled (parsed) expressions, keyed by their
  # text. Parsing is the most expensive step of an evaluation, while the parsed
  # tree doesn't depend on the variables, so it can be reused for any context.
  #
  class ExpressionCache
    def initialize(max_size)
      @max_size = max_size
      @entries = {}
      @mutex = Mutex.new
    end

    attr_reader :max_size

    def max_size=(size)
      @mutex.synchronize do
        @max_size = size
        evict
      end
    end

    # Returns the cached value for the key, or stores the block's result.
    def fetch(key)
      return yield if @max_size.nil? || @max_size <= 0

      @mutex.synchronize do
        if @entries.key?(key)
          # move to the end: most recently used
          value = @entries.delete(key)
          return @entries[key] = value
        end
      end

      # build outside of the lock: parsing may be slow
      value = yield
      @mutex.synchronize do
        @entries[key] ||= value
        evict
        @entries[key]
      end
    end

    def size
      @mutex.synchronize { @entries.size }
    end

    def clear
      @mutex.synchronize { @entries.clear }
    end

    private

    def evict
      @entries.shift while @entries.size > @max_size.to_i
    end
  end
end
