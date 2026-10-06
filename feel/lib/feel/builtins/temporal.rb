# frozen_string_literal: true

module FEEL
  module Builtins
    #
    # Temporal built-in functions: the constructors (date, time, date and time,
    # duration, years and months duration) and the temporal functions. See
    # FEEL::Temporal for the Ruby representation of the temporal values.
    #
    module TemporalFunctions
      module_function

      def date(from, month = nil, day = nil)
        return if from.nil?
        return date_of_fields(from, month, day) unless month.nil? && day.nil?

        case from
        when String then Temporal.parse_date(from)
        else Temporal.date_of(from)
        end
      end

      def date_of_fields(year, month, day)
        return unless [year, month, day].all? { |v| v.is_a?(Numeric) && !Temporal.duration?(v) }

        year, month, day = [year, month, day].map(&:to_i)
        Date.new(year, month, day) if Date.valid_date?(year, month, day)
      end

      def time(from, minute = nil, second = nil, offset = nil)
        return if from.nil?
        return time_of_fields(from, minute, second, offset) unless minute.nil? && second.nil?

        from = Temporal.normalize(from)
        case from
        when String then Temporal.parse_time(from)
        when LocalTime, ZonedTime then from
        when LocalDateTime then from.local_time
        when ActiveSupport::TimeWithZone
          ZonedTime.new(local_time_of(from), from.utc_offset, Temporal.zone_id(from))
        when Time then ZonedTime.new(local_time_of(from), from.utc_offset)
        when Date then ZonedTime.new(LocalTime.new(0, 0, 0), 0)
        end
      end

      def time_of_fields(hour, minute, second, offset)
        return unless [hour, minute, second].all? { |v| v.is_a?(Numeric) && !Temporal.duration?(v) }

        second = Temporal.normalize_number(second.to_r)
        local = Temporal.local_time(hour.to_i, minute.to_i, second)
        return if local.nil?
        return local if offset.nil?
        return unless Temporal.days_time_duration?(offset)

        ZonedTime.new(local, Temporal.total_seconds(offset).to_i)
      end

      def local_time_of(date_time)
        Temporal.wall_clock(date_time).local_time
      end

      def date_and_time(from, time = nil)
        return if from.nil?
        return combine_date_and_time(from, time) unless time.nil?

        from = Temporal.normalize(from)
        case from
        when String then Temporal.parse_date_time(from)
        when LocalDateTime, Time, ActiveSupport::TimeWithZone then from
        when Date then LocalDateTime.new(from.year, from.month, from.day)
        end
      end

      def combine_date_and_time(from, time)
        from = Temporal.normalize(from)
        return unless Temporal.date?(from) || Temporal.date_time?(from)
        return with_time_zone(from, time) if time.is_a?(String)

        date = Temporal.date_of(from)
        local = time.is_a?(ZonedTime) ? time.local_time : time
        return unless local.is_a?(LocalTime)

        fields = [date.year, date.month, date.day, local.hour, local.minute, local.second + local.fraction]
        case time
        when LocalTime then LocalDateTime.new(*fields)
        when ZonedTime
          if time.zone
            Temporal.time_zone(time.zone)&.local(*fields)
          else
            Temporal.offset_time(*fields, time.offset)
          end
        end
      end

      # date and time(date and time, timezone): the same instant in another
      # zone, or a local date-time placed in the zone.
      def with_time_zone(from, zone_id)
        return unless Temporal.date_time?(from)

        if zone_id.match?(/\A(Z|[+-]\d{2}:\d{2})\z/)
          offset = Temporal.parse_offset(zone_id)
          if from.is_a?(LocalDateTime)
            Temporal.offset_time(from.year, from.month, from.day, from.hour, from.min, from.sec + from.fraction, offset)
          else
            from.to_time.getlocal(Temporal.format_offset(offset, utc: "+00:00"))
          end
        else
          zone = Temporal.time_zone(zone_id)
          return if zone.nil?

          from.is_a?(LocalDateTime) ? from.to_time(zone) : from.in_time_zone(zone)
        end
      end

      def duration(from, to = nil)
        return if from.nil?
        # Not in the FEEL spec (extension kept for compatibility): the days
        # between two dates.
        return duration_between(from, to) unless to.nil?

        case from
        when String then Temporal.parse_duration(from)
        when ActiveSupport::Duration then from
        end
      end

      def duration_between(from, to)
        from = from.is_a?(String) ? Temporal.parse_date(from) : Temporal.date_of(from)
        to = to.is_a?(String) ? Temporal.parse_date(to) : Temporal.date_of(to)
        return if from.nil? || to.nil?

        Temporal.days_time_duration((to - from).to_i * 86_400)
      end

      def years_and_months_duration(from, to)
        from = Temporal.date_of(from)
        to = Temporal.date_of(to)
        return if from.nil? || to.nil?

        months = ((to.year * 12) + to.month) - ((from.year * 12) + from.month)
        months -= 1 if months.positive? && to.day < from.day
        months += 1 if months.negative? && to.day > from.day
        Temporal.years_months_duration(months)
      end

      def now
        Time.zone ? Time.zone.now : Time.now
      end

      def today
        Time.zone ? Time.zone.today : Date.today
      end

      # Applies the block to the date of a date or date-time argument.
      def with_date(value)
        date = Temporal.date_of(value) unless value.nil?
        yield date if date
      end
    end

    TEMPORAL = {
      "date": ->(from, month = nil, day = nil) { TemporalFunctions.date(from, month, day) },
      "time": ->(from, minute = nil, second = nil, offset = nil) { TemporalFunctions.time(from, minute, second, offset) },
      "date and time": ->(from, time = nil) { TemporalFunctions.date_and_time(from, time) },
      "duration": ->(from, to = nil) { TemporalFunctions.duration(from, to) },
      "years and months duration": ->(from, to) { TemporalFunctions.years_and_months_duration(from, to) },
      "now": ->() { TemporalFunctions.now },
      "today": ->() { TemporalFunctions.today },
      "day of week": ->(date) {
        TemporalFunctions.with_date(date) { |d| Date::DAYNAMES[d.wday] }
      },
      "day of year": ->(date) {
        TemporalFunctions.with_date(date, &:yday)
      },
      "week of year": ->(date) {
        TemporalFunctions.with_date(date, &:cweek)
      },
      "month of year": ->(date) {
        TemporalFunctions.with_date(date) { |d| Date::MONTHNAMES[d.month] }
      },
      "last day of month": ->(date) {
        TemporalFunctions.with_date(date) { |d| Date.new(d.year, d.month, -1) }
      },
      # Extends the numeric abs() (Builtins::NUMERIC, merged before this hash)
      # to durations. TODO: move into builtins/numeric.rb.
      "abs": ->(n) {
        if Temporal.duration?(n)
          Temporal.abs(n)
        else
          Builtins::NUMERIC[:abs].call(n)
        end
      },
    }.freeze
  end
end
