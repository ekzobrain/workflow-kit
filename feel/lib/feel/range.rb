# frozen_string_literal: true

require "json"

module FEEL
  #
  # A FEEL range value, e.g. `[1..10]`, `(1..10]`, `]1..10[` or the open-ended
  # `< 10` (passed as a function argument), or created from Ruby with
  # `FEEL::Range.new(1, 10)`.
  #
  # A `nil` start/end means the range is unbounded on that side.
  #
  # Note: inside `module FEEL`, `Range` refers to this class. Use `::Range`
  # for Ruby ranges.
  #
  class Range
    include Values

    # Sentinels for the unbounded side of a range.
    NEGATIVE_INFINITY = Object.new.freeze
    POSITIVE_INFINITY = Object.new.freeze

    attr_reader :start, :end, :start_included, :end_included

    def initialize(start_value, end_value, start_included = true, end_included = true)
      @start = start_value
      @end = end_value
      @start_included = start_value.nil? ? false : start_included
      @end_included = end_value.nil? ? false : end_included
    end

    # Builds a range from endpoint values, or returns nil if the endpoints are
    # not a valid range definition (missing, or of different types).
    def self.build(start_value, end_value, start_included = true, end_included = true)
      return nil if start_value.nil? && end_value.nil?

      start_kind = kind(start_value) unless start_value.nil?
      end_kind = kind(end_value) unless end_value.nil?
      return nil if start_kind.nil? && !start_value.nil?
      return nil if end_kind.nil? && !end_value.nil?
      return nil if start_kind && end_kind && start_kind != end_kind

      new(start_value, end_value, start_included, end_included)
    end

    # The kind of a value that can be an endpoint of a range. Values of the same
    # kind can be compared with each other. Returns nil for non-comparable values.
    def self.kind(value)
      case value
      when nil, true, false then nil
      when Numeric then :number
      when String then :string
      when ->(v) { Temporal.temporal?(v) } then Temporal.kind(value)
      when Array, Hash, Range, ::Range then nil
      when Comparable then value.class
      end
    end

    # A point value that can be used with the range built-in functions
    # (numbers and temporal values).
    def self.point?(value)
      kind = kind(value)
      !kind.nil? && kind != :string
    end

    # Compares two endpoint values (which may be the infinity sentinels).
    # Returns -1, 0, 1 or nil if the values are not comparable.
    def self.compare_values(left, right)
      return 0 if left.equal?(right)
      return -1 if left.equal?(NEGATIVE_INFINITY) || right.equal?(POSITIVE_INFINITY)
      return 1 if left.equal?(POSITIVE_INFINITY) || right.equal?(NEGATIVE_INFINITY)

      left <=> right
    rescue ArgumentError, NoMethodError, TypeError
      nil
    end

    # The start value, or a sentinel lower than any value if unbounded.
    def lower_bound
      start.nil? ? NEGATIVE_INFINITY : start
    end

    # The end value, or a sentinel greater than any value if unbounded.
    def upper_bound
      self.end.nil? ? POSITIVE_INFINITY : self.end
    end

    # The kind of the range endpoints (see Range.kind).
    def kind
      Range.kind(start.nil? ? self.end : start)
    end

    # A value of the range, used to check that a value is comparable with it.
    def sample
      start.nil? ? self.end : start
    end

    # Checks whether the value is in the range. Returns nil if the value is not
    # comparable with the range endpoints.
    def include?(value)
      return nil if value.nil?

      lower = start.nil? ? true : feel_compare(start_included ? ">=" : ">", value, start)
      upper = self.end.nil? ? true : feel_compare(end_included ? "<=" : "<", value, self.end)
      return nil if lower.nil? || upper.nil?

      lower && upper
    end
    alias_method :member?, :include?
    alias_method :===, :include?

    def ==(other)
      other.is_a?(Range) &&
        start == other.start && self.end == other.end &&
        start_included == other.start_included && end_included == other.end_included
    end
    alias_method :eql?, :==

    def hash
      [self.class, start, self.end, start_included, end_included].hash
    end

    # FEEL string representation, as feel-scala's ValRange#toString:
    # "[1..10]", "(1..10)", and "< 5" / ">= 5" for open-ended ranges.
    # Endpoint values are printed with `to_s` (pass a block to format them,
    # e.g. `range.to_feel_string { |v| feel_string(v) }`).
    def to_feel_string(&format)
      format ||= :to_s.to_proc
      return "#{end_included ? "<=" : "<"} #{format.call(self.end)}" if start.nil?
      return "#{start_included ? ">=" : ">"} #{format.call(start)}" if self.end.nil?

      "#{start_included ? "[" : "("}#{format.call(start)}..#{format.call(self.end)}#{end_included ? "]" : ")"}"
    end
    alias_method :to_s, :to_feel_string

    # JSON representation is the FEEL string (feel-scala: `to json((1..10])` is `"(1..10]"`).
    def as_json(*)
      to_feel_string
    end

    def to_json(*args)
      to_feel_string.to_json(*args)
    end

    def inspect
      "#<FEEL::Range #{self}>"
    end
  end
end
