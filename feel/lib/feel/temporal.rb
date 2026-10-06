# frozen_string_literal: true

require "bigdecimal"

module FEEL
  #
  # Temporal values (date, time, date and time, durations).
  #
  # Mapping of the FEEL temporal types (as distinguished by feel-scala) to Ruby:
  #
  # | FEEL type                        | Ruby value                                           |
  # |----------------------------------|------------------------------------------------------|
  # | date                             | `Date` (exactly `Date`, not `DateTime`)              |
  # | time (local, no offset)          | `FEEL::LocalTime`                                    |
  # | time with offset / zone          | `FEEL::ZonedTime` (local time + offset + zone id)    |
  # | date and time (local, no offset) | `FEEL::LocalDateTime`                                |
  # | date and time with offset        | `Time` (fixed UTC offset, or the system zone)        |
  # | date and time with zone id       | `Time` with a `TZInfo::Timezone` (`@Europe/Paris`)   |
  # | years and months duration        | `FEEL::Duration` (whole months)                      |
  # | days and time duration           | `FEEL::Duration` (exact seconds)                     |
  #
  # Values passed in as variables are converted on input (`Temporal.normalize`):
  # `DateTime` becomes a `Time` with the same offset. If ActiveSupport is used
  # by the application, `ActiveSupport::TimeWithZone` becomes a `Time` with its
  # zone and `ActiveSupport::Duration` a `FEEL::Duration` (a duration that
  # mixes years/months with days/time parts, e.g. `1.month + 2.days`, becomes
  # a days and time duration of the same number of seconds).
  #
  # Local values never carry an offset: `FEEL::LocalTime`/`FEEL::LocalDateTime`
  # mean "no offset", while UTC is a `ZonedTime`/`Time` with offset 0 ("Z").
  #
  # Interop extension (feel-scala returns null here): a local date-time can be
  # compared with / subtracted from a date-time with offset or zone. The local
  # date-time is then interpreted in the offset of the other value (wall-clock
  # comparison), since Ruby has no offset-less date-time type of its own.
  #
  class LocalTime
    include Comparable

    SECONDS_PER_DAY = 86_400

    # Seconds since midnight (Integer or Rational), 0 <= seconds < 86400.
    attr_reader :seconds

    def self.from_seconds(seconds)
      instance = allocate
      instance.instance_variable_set(:@seconds, seconds % SECONDS_PER_DAY)
      instance
    end

    def initialize(hour, minute, second = 0)
      raise ArgumentError, "invalid time" unless Temporal.valid_time?(hour, minute, second)

      @seconds = (hour * 3600) + (minute * 60) + second
    end

    def hour = seconds.to_i / 3600
    def minute = (seconds.to_i % 3600) / 60
    def second = seconds.to_i % 60
    alias_method :min, :minute
    alias_method :sec, :second

    # Fraction of the second (Rational, 0 <= fraction < 1).
    def fraction = seconds - seconds.floor

    def +(other)
      LocalTime.from_seconds(seconds + other)
    end

    def -(other)
      LocalTime.from_seconds(seconds - other)
    end

    def <=>(other)
      seconds <=> other.seconds if other.is_a?(LocalTime)
    end

    def ==(other)
      other.is_a?(LocalTime) && seconds == other.seconds
    end
    alias_method :eql?, :==

    def hash = [self.class, seconds].hash

    def to_s
      format("%02d:%02d:%02d", hour, minute, second) + Temporal.format_fraction(fraction)
    end
    alias_method :iso8601, :to_s

    def as_json(*) = iso8601
    def to_json(*args) = iso8601.to_json(*args)

    def inspect = "#<FEEL::LocalTime #{self}>"
  end

  class ZonedTime
    include Comparable

    attr_reader :local_time, :offset, :zone

    # local_time: FEEL::LocalTime, offset: seconds east of UTC, zone: zone id or nil
    def initialize(local_time, offset, zone = nil)
      @local_time = local_time
      @offset = offset
      @zone = zone
    end

    def hour = local_time.hour
    def minute = local_time.minute
    def second = local_time.second
    alias_method :min, :minute
    alias_method :sec, :second
    alias_method :utc_offset, :offset

    def utc_seconds = local_time.seconds - offset

    def +(other)
      ZonedTime.new(local_time + other, offset, zone)
    end

    def -(other)
      ZonedTime.new(local_time - other, offset, zone)
    end

    def <=>(other)
      utc_seconds <=> other.utc_seconds if other.is_a?(ZonedTime)
    end

    def ==(other)
      other.is_a?(ZonedTime) && local_time == other.local_time && offset == other.offset && zone == other.zone
    end
    alias_method :eql?, :==

    def hash = [self.class, local_time, offset, zone].hash

    # FEEL representation: `10:00:00+01:00` or `10:00:00@Europe/Paris`.
    def to_s
      zone ? "#{local_time}@#{zone}" : iso8601
    end

    # ISO 8601 representation (always with the offset).
    def iso8601
      "#{local_time}#{Temporal.format_offset(offset)}"
    end

    def as_json(*) = iso8601
    def to_json(*args) = iso8601.to_json(*args)

    def inspect = "#<FEEL::ZonedTime #{self}>"
  end

  class LocalDateTime
    include Comparable

    # The wall-clock date and time, stored as a UTC `Time`.
    attr_reader :time

    def self.from_time(time)
      instance = allocate
      instance.instance_variable_set(:@time, time)
      instance
    end

    def initialize(year, month, day, hour = 0, minute = 0, second = 0)
      raise ArgumentError, "invalid date" unless Date.valid_date?(year, month, day)
      raise ArgumentError, "invalid time" unless Temporal.valid_time?(hour, minute, second)

      @time = Time.utc(year, month, day, hour, minute, second)
    end

    def year = time.year
    def month = time.month
    def day = time.day
    def hour = time.hour
    def min = time.min
    def sec = time.sec
    def wday = time.wday
    def yday = time.yday
    def to_date = Date.new(year, month, day)
    alias_method :minute, :min
    alias_method :second, :sec

    def cwday = to_date.cwday
    def cweek = to_date.cweek
    def fraction = time.subsec

    def local_time = LocalTime.from_seconds((hour * 3600) + (min * 60) + sec + fraction)

    # Interprets the local date-time in the given zone (a zone id or a
    # `TZInfo::Timezone`; default: the zone of `FEEL.config.time_zone`, or the
    # system zone).
    def to_time(zone = Temporal.default_zone)
      args = [year, month, day, hour, min, sec + fraction]
      zone = Temporal.zone(zone) if zone.is_a?(String)
      zone ? Temporal.local_in_zone(*args, zone) : Time.local(*args)
    end

    def to_datetime = to_time.to_datetime

    def +(other)
      LocalDateTime.from_time(time + other)
    end

    def -(other)
      return time - other.time if other.is_a?(LocalDateTime)

      LocalDateTime.from_time(time - other)
    end

    def add_months(months)
      LocalDateTime.from_time(Temporal.add_months(time, months))
    end

    def <=>(other)
      time <=> other.time if other.is_a?(LocalDateTime)
    end

    def ==(other)
      other.is_a?(LocalDateTime) && time == other.time
    end
    alias_method :eql?, :==

    def hash = [self.class, time].hash

    def to_s
      "#{to_date.iso8601}T#{local_time}"
    end
    alias_method :iso8601, :to_s

    def as_json(*) = iso8601
    def to_json(*args) = iso8601.to_json(*args)

    def inspect = "#<FEEL::LocalDateTime #{self}>"
  end

  module Temporal
    module_function

    YEAR_MONTH_PARTS = %i[years months].freeze
    DAY_TIME_PARTS = %i[weeks days hours minutes seconds].freeze

    YEAR = '(-?(?:[1-9]\d{0,4})?\d{4})'
    DATE = "#{YEAR}-([01]\\d)-([0-3]\\d)"
    FRACTION = '(?:\.(\d{1,9}))?'
    LOCAL_TIME = "(\\d{2}):(\\d{2})(?::(\\d{2}))?#{FRACTION}"
    OFFSET = '(Z|[+-]\d{2}:\d{2})'

    DATE_PATTERN = /\A#{DATE}\z/
    LOCAL_TIME_PATTERN = /\AT?#{LOCAL_TIME}\z/
    OFFSET_TIME_PATTERN = /\AT?(\d{2}):(\d{2}):(\d{2})#{FRACTION}(?:#{OFFSET}|@(.+))\z/
    LOCAL_DATE_TIME_PATTERN = /\A#{DATE}T#{LOCAL_TIME}\z/
    OFFSET_DATE_TIME_PATTERN = /\A#{DATE}T#{LOCAL_TIME}(?:#{OFFSET}(?:\[(.+)\])?|@(.+))\z/
    YEAR_MONTH_DURATION_PATTERN = /\A(-)?P(?:(-?\d+)Y)?(?:(-?\d+)M)?\z/
    DAY_TIME_DURATION_PATTERN = /\A(-)?P(?:(-?\d+)D)?(?:T(?:(-?\d+)H)?(?:(-?\d+)M)?(?:(-?\d+(?:\.\d*)?)S)?)?\z/

    #
    # Parsing
    #

    # Parses the string of an `@"..."` literal.
    def parse_literal(value)
      return nil unless value.is_a?(String)

      if DATE_PATTERN.match?(value) then parse_date(value)
      elsif OFFSET_TIME_PATTERN.match?(value) then parse_time(value)
      elsif OFFSET_DATE_TIME_PATTERN.match?(value) || LOCAL_DATE_TIME_PATTERN.match?(value) then parse_date_time(value)
      elsif value.match?(/\A-?P/) then parse_duration(value)
      else parse_time(value)
      end
    end

    def parse_date(value)
      match = DATE_PATTERN.match(value.to_s)
      return nil unless match

      year, month, day = match.captures.map(&:to_i)
      Date.new(year, month, day) if Date.valid_date?(year, month, day)
    end

    def parse_time(value)
      value = value.to_s
      if (match = OFFSET_TIME_PATTERN.match(value))
        hour, minute, second, fraction, offset, zone_id = match.captures
        local = local_time(hour.to_i, minute.to_i, second.to_i + parse_fraction(fraction))
        return nil unless local
        return ZonedTime.new(local, parse_offset(offset)) if offset

        tz = zone(zone_id)
        tz && ZonedTime.new(local, tz.current_period.base_utc_offset, tz.identifier)
      elsif (match = LOCAL_TIME_PATTERN.match(value))
        hour, minute, second, fraction = match.captures
        local_time(hour.to_i, minute.to_i, second.to_i + parse_fraction(fraction))
      end
    end

    def parse_date_time(value)
      value = value.to_s
      if DATE_PATTERN.match?(value)
        date = parse_date(value)
        return date && LocalDateTime.new(date.year, date.month, date.day)
      end

      if (match = OFFSET_DATE_TIME_PATTERN.match(value))
        year, month, day, hour, minute, second, fraction, offset, bracket_zone, at_zone = match.captures
        fields = [year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, second.to_i + parse_fraction(fraction)]
        return nil unless valid_date_time?(*fields)

        zone_id = bracket_zone || at_zone
        if zone_id
          tz = zone(zone_id)
          return nil if tz.nil?

          # "...+02:00[Europe/Berlin]": the offset selects the instant (e.g. in
          # the overlap at the end of the daylight saving time)
          offset ? offset_time(*fields, parse_offset(offset)).getlocal(tz) : local_in_zone(*fields, tz)
        else
          offset_time(*fields, parse_offset(offset))
        end
      elsif (match = LOCAL_DATE_TIME_PATTERN.match(value))
        year, month, day, hour, minute, second, fraction = match.captures
        fields = [year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, second.to_i + parse_fraction(fraction)]
        LocalDateTime.new(*fields) if valid_date_time?(*fields)
      end
    end

    def parse_duration(value)
      value = value.to_s
      if (match = YEAR_MONTH_DURATION_PATTERN.match(value))
        sign, years, months = match.captures
        return nil if years.nil? && months.nil?

        total = (years.to_i * 12) + months.to_i
        years_months_duration(sign ? -total : total)
      elsif (match = DAY_TIME_DURATION_PATTERN.match(value))
        sign, days, hours, minutes, seconds = match.captures
        return nil if [days, hours, minutes, seconds].all?(&:nil?)
        return nil if value.end_with?("T")

        total = (days.to_i * 86_400) + (hours.to_i * 3600) + (minutes.to_i * 60) + (seconds ? seconds.to_r : 0)
        days_time_duration(sign ? -total : total)
      end
    end

    def parse_fraction(fraction)
      fraction ? Rational(fraction.to_i, 10**fraction.length) : 0
    end

    def parse_offset(offset)
      return 0 if offset == "Z"

      sign = offset.start_with?("-") ? -1 : 1
      hours, minutes = offset[1..].split(":").map(&:to_i)
      sign * ((hours * 3600) + (minutes * 60))
    end

    # The TZInfo::Timezone of a zone id (e.g. "Europe/Berlin"), or nil.
    def zone(zone_id)
      return zone_id if zone_id.is_a?(TZInfo::Timezone)

      TZInfo::Timezone.get(zone_id)
    rescue TZInfo::InvalidTimezoneIdentifier, ArgumentError
      nil
    end

    # The zone of `now()` / `today()`: `FEEL.config.time_zone`, else the
    # ActiveSupport `Time.zone` if the application uses it, else nil (the
    # system zone).
    def default_zone
      configured = FEEL.config.time_zone
      return zone(configured) if configured
      return Time.zone.tzinfo if Time.respond_to?(:zone) && Time.zone.respond_to?(:tzinfo)

      nil
    end

    def now
      tz = default_zone
      tz ? Time.now.getlocal(tz) : Time.now
    end

    def today
      date_of(now)
    end

    # A date-time in a zone (a `Time` with the TZInfo::Timezone as zone). Like
    # java.time.ZonedDateTime: a local time in a gap (e.g. at the start of the
    # daylight saving time) is moved forward by the length of the gap, an
    # ambiguous local time uses the earlier offset.
    def local_in_zone(year, month, day, hour, minute, second, tz)
      wall = Time.utc(year, month, day, hour, minute, second)
      periods = tz.periods_for_local(wall)
      offset = if periods.empty?
        tz.period_for_utc(wall - 86_400).utc_total_offset
      else
        periods.first.utc_total_offset
      end
      (wall - offset).getlocal(tz)
    end

    def zoned?(value)
      Time === value && value.zone.is_a?(TZInfo::Timezone)
    end

    # Adds months to a date-time (a UTC `Time` holding a wall-clock time, a
    # `Time` with offset or a `Time` with zone), keeping the time of day; the
    # day is clamped to the end of the month.
    def add_months(time, months)
      date = Date.new(time.year, time.month, time.day) >> months
      fields = [date.year, date.month, date.day, time.hour, time.min, time.sec + time.subsec]
      if zoned?(time) then local_in_zone(*fields, time.zone)
      elsif time.utc? then Time.utc(*fields)
      else Time.new(*fields, format_offset(time.utc_offset, utc: "+00:00"))
      end
    end

    #
    # Construction
    #

    def valid_time?(hour, minute, second)
      [hour, minute, second].all? { |v| v.is_a?(Numeric) } &&
        hour.between?(0, 23) && minute.between?(0, 59) && second >= 0 && second < 60
    end

    def valid_date_time?(year, month, day, hour, minute, second)
      Date.valid_date?(year, month, day) && valid_time?(hour, minute, second)
    end

    def local_time(hour, minute, second)
      LocalTime.new(hour, minute, second) if valid_time?(hour, minute, second)
    end

    # A date-time with a fixed offset (seconds east of UTC).
    def offset_time(year, month, day, hour, minute, second, offset)
      Time.new(year, month, day, hour, minute, second, format_offset(offset, utc: "+00:00"))
    end

    def years_months_duration(total_months)
      Duration.years_months(total_months.to_i)
    end

    def days_time_duration(total_seconds)
      Duration.days_time(total_seconds)
    end

    def normalize_number(value)
      return value unless value.is_a?(Rational) || value.is_a?(BigDecimal)

      value.denominator == 1 ? value.to_i : value
    rescue NoMethodError
      value
    end

    # Converts a numeric result (e.g. of duration / duration) to Integer or Float.
    def to_number(value)
      value = value.to_r
      value.denominator == 1 ? value.to_i : value.to_f
    end

    #
    # Classification
    #

    def duration?(value)
      Duration === value || active_support_duration?(value)
    end

    def years_months_duration?(value)
      value = normalize(value)
      Duration === value && value.years_months?
    end

    def days_time_duration?(value)
      value = normalize(value)
      Duration === value && value.days_time?
    end

    def date?(value)
      value.instance_of?(Date)
    end

    def time?(value)
      value.is_a?(LocalTime) || value.is_a?(ZonedTime)
    end

    # A date-time with an offset or a zone (absolute point in time).
    def absolute_date_time?(value)
      Time === value || DateTime === value || time_with_zone?(value)
    end

    def date_time?(value)
      value.is_a?(LocalDateTime) || absolute_date_time?(value)
    end

    def temporal?(value)
      return false if value.nil? || value == true || value == false

      duration?(value) || value.is_a?(Date) || time?(value) || date_time?(value)
    end

    # The FEEL type kind of a temporal value, or nil.
    def kind(value)
      value = normalize(value)
      if Duration === value then value.kind
      elsif date?(value) then :date
      elsif time?(value) then :time
      elsif date_time?(value) then :date_time
      end
    end

    def instance_of_type?(value, type_name)
      case type_name
      when "date" then date?(value)
      when "time" then time?(value)
      when "date and time" then date_time?(value)
      when "duration" then duration?(value)
      when "years and months duration" then years_months_duration?(value)
      when "days and time duration" then days_time_duration?(value)
      else false
      end
    end

    # Converts temporal values of other Ruby types to the FEEL representation:
    # `DateTime` to `Time`, and (if ActiveSupport is used) TimeWithZone to a
    # zoned `Time` and ActiveSupport::Duration to a FEEL::Duration. Other
    # values are returned as is.
    def normalize(value)
      if DateTime === value then value.to_time
      elsif time_with_zone?(value) then Time.at(value.to_r).getlocal(value.time_zone.tzinfo)
      elsif active_support_duration?(value) then from_active_support_duration(value)
      else value
      end
    end

    def active_support_duration?(value)
      defined?(ActiveSupport::Duration) ? ActiveSupport::Duration === value : false
    end

    def time_with_zone?(value)
      defined?(ActiveSupport::TimeWithZone) ? ActiveSupport::TimeWithZone === value : false
    end

    def from_active_support_duration(duration)
      parts = duration.parts
      if !parts.empty? && (parts.keys - YEAR_MONTH_PARTS).empty?
        years_months_duration(((parts[:years] || 0) * 12) + (parts[:months] || 0))
      elsif (parts.keys - DAY_TIME_PARTS).empty?
        seconds = ((parts[:weeks] || 0) * 604_800) + ((parts[:days] || 0) * 86_400) +
          ((parts[:hours] || 0) * 3600) + ((parts[:minutes] || 0) * 60) + (parts[:seconds] || 0).to_r
        days_time_duration(seconds)
      else
        days_time_duration(duration.value.to_r)
      end
    end

    def date_of(value)
      value = normalize(value)
      if date?(value) then value
      elsif date_time?(value) then Date.new(value.year, value.month, value.day)
      end
    end

    def total_months(duration)
      normalize(duration).total_months
    end

    def total_seconds(duration)
      normalize(duration).total_seconds
    end

    def wall_clock(value)
      value = normalize(value)
      return value if value.is_a?(LocalDateTime)

      LocalDateTime.from_time(Time.utc(value.year, value.month, value.day, value.hour, value.min, value.sec + value.subsec))
    end

    def zone_id(value)
      value = normalize(value)
      value.zone.identifier if zoned?(value)
    end

    #
    # Properties
    #

    def property(value, name)
      value = normalize(value)
      case kind(value)
      when :date
        date_property(value, name)
      when :date_time
        date_property(value, name) || time_property(value, name)
      when :time
        time_property(value, name)
      when :years_months_duration
        months = total_months(value)
        sign = months.negative? ? -1 : 1
        case name
        when "years" then months.abs / 12 * sign
        when "months" then months.abs % 12 * sign
        end
      when :days_time_duration
        seconds = total_seconds(value).to_i
        sign = seconds.negative? ? -1 : 1
        seconds = seconds.abs
        case name
        when "days" then seconds / 86_400 * sign
        when "hours" then seconds / 3600 % 24 * sign
        when "minutes" then seconds / 60 % 60 * sign
        when "seconds" then seconds % 60 * sign
        end
      end
    end

    def date_property(value, name)
      case name
      when "year" then value.year
      when "month" then value.month
      when "day" then value.day
      when "weekday" then date_of(value).cwday
      end
    end

    def time_property(value, name)
      case name
      when "hour" then value.hour
      when "minute" then value.min
      when "second" then value.sec
      when "time offset"
        if value.is_a?(ZonedTime) || absolute_date_time?(value)
          days_time_duration(value.utc_offset)
        end
      when "timezone"
        if value.is_a?(ZonedTime) then value.zone
        else zone_id(value)
        end
      end
    end

    #
    # Equality and comparison
    #

    # Three-way comparison of two temporal values, or nil if not comparable.
    def compare_values(left, right)
      left = normalize(left)
      right = normalize(right)
      left_kind = kind(left)
      right_kind = kind(right)
      return nil if left_kind.nil? || right_kind.nil?

      return nil unless left_kind == right_kind

      case left_kind
      when :date then left <=> right
      when :time then left <=> right
      when :date_time
        if left.is_a?(LocalDateTime) || right.is_a?(LocalDateTime)
          wall_clock(left) <=> wall_clock(right)
        else
          left.to_r <=> right.to_r
        end
      when :years_months_duration then total_months(left) <=> total_months(right)
      when :days_time_duration then total_seconds(left) <=> total_seconds(right)
      end
    end

    def compare(operator, left, right)
      result = compare_values(left, right)
      return nil if result.nil?

      result.public_send(operator, 0)
    end

    def equal(left, right)
      left = normalize(left)
      right = normalize(right)
      return left == right if kind(left) == :time && kind(right) == :time

      compare_values(left, right)&.zero? || false
    end

    #
    # Arithmetic
    #

    def add(left, right)
      left = normalize(left)
      right = normalize(right)
      if duration?(left) && duration?(right)
        combine_durations(left, right, 1)
      elsif duration?(right)
        plus(left, right, 1)
      elsif duration?(left)
        plus(right, left, 1)
      end
    end

    def subtract(left, right)
      left = normalize(left)
      right = normalize(right)
      return combine_durations(left, right, -1) if duration?(left) && duration?(right)
      return plus(left, right, -1) if duration?(right)

      case [kind(left), kind(right)]
      when %i[date date]
        days_time_duration((left - right).to_i * 86_400)
      when %i[time time]
        if left.is_a?(LocalTime) && right.is_a?(LocalTime)
          days_time_duration(left.seconds - right.seconds)
        elsif left.is_a?(ZonedTime) && right.is_a?(ZonedTime)
          days_time_duration(left.utc_seconds - right.utc_seconds)
        end
      when %i[date_time date_time]
        if left.is_a?(LocalDateTime) || right.is_a?(LocalDateTime)
          days_time_duration(wall_clock(left) - wall_clock(right))
        else
          days_time_duration(left.to_r - right.to_r)
        end
      end
    end

    def combine_durations(left, right, sign)
      left_kind = kind(left)
      right_kind = kind(right)
      if left_kind == :years_months_duration && right_kind == :years_months_duration
        years_months_duration(total_months(left) + (sign * total_months(right)))
      elsif left_kind == :days_time_duration && right_kind == :days_time_duration
        days_time_duration(total_seconds(left) + (sign * total_seconds(right)))
      end
    end

    # Adds (sign = 1) or subtracts (sign = -1) a duration to/from a temporal value.
    def plus(value, duration, sign)
      case kind(duration)
      when :years_months_duration
        months = sign * total_months(duration)
        case kind(value)
        when :date then value >> months
        when :date_time then value.is_a?(LocalDateTime) ? value.add_months(months) : add_months(value, months)
        end
      when :days_time_duration
        seconds = sign * total_seconds(duration)
        case kind(value)
        when :date then value + (seconds / 86_400r).floor
        when :date_time, :time then value + seconds
        end
      end
    end

    def multiply(left, right)
      left = normalize(left)
      right = normalize(right)
      duration, number = duration?(left) ? [left, right] : [right, left]
      return nil unless duration?(duration) && Numbers.number?(number)

      factor = exact_number(number)
      return nil if factor.nil?

      case kind(duration)
      when :years_months_duration then years_months_duration(round_months(total_months(duration) * factor))
      when :days_time_duration then days_time_duration(truncate_nanos(total_seconds(duration).to_r * factor))
      end
    end

    def divide(left, right)
      left = normalize(left)
      right = normalize(right)
      return nil unless duration?(left)

      if duration?(right)
        return nil if right.zero?

        case [kind(left), kind(right)]
        when %i[years_months_duration years_months_duration]
          to_number(Rational(total_months(left), total_months(right)))
        when %i[days_time_duration days_time_duration]
          to_number(total_seconds(left).to_r / total_seconds(right))
        end
      elsif Numbers.number?(right)
        divisor = exact_number(right)
        return nil if divisor.nil? || divisor.zero?

        case kind(left)
        when :years_months_duration then years_months_duration(round_months(total_months(left) / divisor))
        when :days_time_duration then days_time_duration(truncate_nanos(total_seconds(left).to_r / divisor))
        end
      end
    end

    # A number as exact Rational (Floats via their decimal representation).
    def exact_number(number)
      decimal = Numbers.decimal(number)
      decimal&.to_r
    end

    # Months of a multiplied/divided years-months duration: rounded to the
    # nearest month, halves up (XPath op:multiply-yearMonthDuration).
    def round_months(months)
      (months.to_r + Rational(1, 2)).floor
    end

    # Seconds of a multiplied/divided days-time duration, truncated to
    # nanoseconds (the precision of formatted durations).
    def truncate_nanos(seconds)
      Rational((seconds * 1_000_000_000).truncate, 1_000_000_000)
    end

    def abs(duration)
      duration = normalize(duration)
      duration?(duration) ? duration.abs : duration
    end

    #
    # Formatting
    #

    def format_fraction(fraction)
      return "" if fraction.nil? || fraction.zero?

      digits = format("%.9f", fraction.to_r)[2..].sub(/0+\z/, "")
      ".#{digits}"
    end

    # Formats an offset in seconds as `+01:00` (`Z` for zero by default).
    def format_offset(offset, utc: "Z")
      return utc if offset.zero?

      sign = offset.negative? ? "-" : "+"
      hours, rest = offset.abs.divmod(3600)
      minutes, seconds = rest.divmod(60)
      result = "#{sign}#{format('%02d:%02d', hours, minutes)}"
      seconds.zero? ? result : "#{result}:#{format('%02d', seconds)}"
    end

    def format_local_date_time(value)
      wall_clock(value).to_s
    end

    # The FEEL string representation of a temporal value (`string()`), or nil
    # if the value is not temporal.
    def format_value(value)
      value = normalize(value)
      case kind(value)
      when :date then value.iso8601
      when :time then value.to_s
      when :date_time
        if value.is_a?(LocalDateTime) then value.to_s
        elsif zoned?(value) then "#{format_local_date_time(value)}@#{zone_id(value)}"
        else "#{format_local_date_time(value)}#{format_offset(value.utc_offset)}"
        end
      when :years_months_duration, :days_time_duration then value.to_s
      end
    end

    # The ISO 8601 representation of a temporal value (as used by `to json()`):
    # times and date-times with a zone id are given with their offset (the
    # zone id is dropped: ISO 8601 has no notation for it).
    def format_iso(value)
      value = normalize(value)
      if ZonedTime === value then value.iso8601
      elsif zoned?(value) then "#{format_local_date_time(value)}#{format_offset(value.utc_offset)}"
      else format_value(value)
      end
    end

    def format_years_months_duration(total)
      return "P0Y" if total.zero?

      sign = total.negative? ? "-" : ""
      years, months = total.abs.divmod(12)
      "#{sign}P#{"#{years}Y" unless years.zero?}#{"#{months}M" unless months.zero?}"
    end

    # Fractions of seconds are kept up to nanoseconds, e.g. "PT1.5S", "-PT0.25S".
    def format_days_time_duration(total)
      total = total.to_r.round(9)
      return "P0D" if total.zero?

      sign = total.negative? ? "-" : ""
      whole = total.abs.floor
      fraction = total.abs - whole
      days, rest = whole.divmod(86_400)
      hours, rest = rest.divmod(3600)
      minutes, seconds = rest.divmod(60)
      seconds_text = format_seconds(seconds + fraction)
      time = "#{"#{hours}H" unless hours.zero?}#{"#{minutes}M" unless minutes.zero?}#{"#{seconds_text}S" if seconds_text}"
      "#{sign}P#{"#{days}D" unless days.zero?}#{"T#{time}" unless time.empty?}"
    end

    # "4", "1.5", "0.000000001", or nil for zero seconds.
    def format_seconds(seconds)
      return nil if seconds.zero?
      return seconds.to_i.to_s if seconds.denominator == 1

      BigDecimal(seconds, 20).round(9).to_s("F").sub(/0+\z/, "")
    end
  end
end
