# frozen_string_literal: true

module FEEL
  #
  # A FEEL duration: either a years and months duration (a whole number of
  # months) or a days and time duration (an exact number of seconds, with
  # fractions up to nanoseconds).
  #
  #   FEEL::Duration.parse("P1Y2M")    # => #<FEEL::Duration P1Y2M>
  #   FEEL::Duration.hours(36).to_s     # => "P1DT12H"
  #   FEEL::Duration.days(1).to_json    # => "\"P1D\""
  #
  class Duration
    include Comparable

    SECONDS_PER_DAY = 86_400

    # :years_months_duration or :days_time_duration
    attr_reader :kind

    # The amount: total months (Integer) or total seconds (Integer or Rational).
    attr_reader :amount

    class << self
      def years_months(total_months)
        new(:years_months_duration, Integer(total_months))
      end

      def days_time(total_seconds)
        seconds = total_seconds.to_r
        new(:days_time_duration, seconds.denominator == 1 ? seconds.to_i : seconds)
      end

      def years(count) = years_months(count * 12)
      def months(count) = years_months(count)
      def weeks(count) = days_time(count * 7 * SECONDS_PER_DAY)
      def days(count) = days_time(count * SECONDS_PER_DAY)
      def hours(count) = days_time(count * 3600)
      def minutes(count) = days_time(count * 60)
      def seconds(count) = days_time(count)

      # Parses an ISO 8601 / FEEL duration ("P1Y2M", "P1DT2H", "-PT1.5S").
      # Returns nil if the text is not a valid years and months or days and
      # time duration.
      def parse(text)
        Temporal.parse_duration(text)
      end

      private :new
    end

    def initialize(kind, amount)
      @kind = kind
      @amount = amount
      freeze
    end

    def years_months?
      kind == :years_months_duration
    end

    def days_time?
      kind == :days_time_duration
    end

    def total_months
      years_months? ? amount : nil
    end

    def total_seconds
      days_time? ? amount : nil
    end

    def zero? = amount.zero?
    def negative? = amount.negative?
    def positive? = amount.positive?

    def -@
      Duration.send(:new, kind, -amount)
    end

    # Sum / difference of two durations of the same kind.
    def +(other)
      raise TypeError, "can't add #{other.inspect} to #{inspect}" unless other.is_a?(Duration) && other.kind == kind

      years_months? ? Duration.years_months(amount + other.amount) : Duration.days_time(amount + other.amount)
    end

    def -(other)
      self + -other
    end

    def abs
      negative? ? -self : self
    end

    # Durations of the same kind are ordered by their amount; durations of
    # different kinds are not comparable.
    def <=>(other)
      amount <=> other.amount if other.is_a?(Duration) && other.kind == kind
    end

    def ==(other)
      other.is_a?(Duration) && other.kind == kind && other.amount == amount
    end
    alias_method :eql?, :==

    def hash = [Duration, kind, amount].hash

    # The FEEL / ISO 8601 representation, e.g. "P1Y2M", "P1DT2H", "-PT1.5S".
    def to_s
      years_months? ? Temporal.format_years_months_duration(amount) : Temporal.format_days_time_duration(amount)
    end
    alias_method :iso8601, :to_s

    def as_json(*) = to_s

    def to_json(*args) = to_s.to_json(*args)

    def inspect = "#<FEEL::Duration #{self}>"

    # An equivalent ActiveSupport::Duration (requires ActiveSupport).
    def to_active_support
      duration = ActiveSupport::Duration.parse(abs.to_s)
      negative? ? -duration : duration
    end
  end
end
