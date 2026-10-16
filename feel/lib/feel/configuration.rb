# frozen_string_literal: true

module FEEL
  class Configuration
    DEFAULT_EXPRESSION_CACHE_SIZE = 1_000

    # Custom functions by name (String or Symbol keys), e.g.
    # `{ "reverse" => ->(s) { s.reverse } }`.
    attr_accessor :functions

    # Strict mode: an expression that can't be computed raises
    # FEEL::EvaluationError instead of returning null (see FEEL::Diagnostics).
    # The default of the `strict:` option of FEEL.evaluate. Default: false.
    attr_reader :strict

    def strict=(value)
      @strict = value
      Diagnostics.update
    end

    # The zone id (e.g. "Europe/Berlin") of `now()` and `today()`. Default:
    # nil, i.e. `Time.zone` of ActiveSupport if the application uses it, else
    # the system zone.
    attr_accessor :time_zone

    # Enables the built-in functions that are Camunda extensions of FEEL
    # (e.g. `uuid()`, `is blank()`, `to json()`, see
    # FEEL::Builtins::CAMUNDA_EXTENSIONS). Default: true.
    attr_accessor :camunda_extensions

    attr_reader :expression_cache_size

    CALENDARS = {
      gregorian: Date::GREGORIAN,
      julian: Date::JULIAN,
      italy: Date::ITALY,
      england: Date::ENGLAND,
    }.freeze

    # The calendar of dates: :gregorian (default, the proleptic Gregorian
    # calendar of ISO 8601, XML Schema and java.time), :julian, :italy (the
    # default of Ruby's Date: Julian before 1582-10-15), :england (Julian
    # before 1752-09-14), or the Julian day number of the calendar reform.
    # Date-times are always Gregorian (Ruby's Time is).
    attr_reader :calendar

    def calendar=(value)
      start = value.is_a?(Numeric) ? value : CALENDARS[value&.to_sym]
      raise ArgumentError, "unknown calendar: #{value.inspect} (expected #{CALENDARS.keys.join(", ")} or a Julian day number)" unless start

      @calendar = value
      @calendar_start = start
    end

    # The `start` of Ruby's Date for the calendar (e.g. Date::GREGORIAN).
    attr_reader :calendar_start

    def initialize
      @functions = {}
      @strict = false
      self.calendar = :gregorian
      @time_zone = nil
      @camunda_extensions = true
      @expression_cache_size = DEFAULT_EXPRESSION_CACHE_SIZE
    end

    # Maximum number of compiled expressions kept by FEEL.compile (and so by
    # FEEL.evaluate / FEEL.test). 0 or nil disables the cache.
    def expression_cache_size=(size)
      @expression_cache_size = size
      FEEL.expression_cache.max_size = size
      FEEL.unary_tests_cache.max_size = size
      FEEL.tree_cache.max_size = size
      FEEL.unary_tests_tree_cache.max_size = size
    end
  end
end
