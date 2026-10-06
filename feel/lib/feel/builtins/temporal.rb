# frozen_string_literal: true

module FEEL
  module Builtins
    TEMPORAL = {
      "date": ->(from, month = nil, day = nil) {
        return if from.nil?
        return Date.new(from, month, day) if from.is_a?(Integer) && month && day
        case from
        when DateTime, Time, ActiveSupport::TimeWithZone then from.to_date
        when Date then from
        when String then Date.parse(from)
        end
      },
      "time": ->(from) {
        return if from.nil?
        case from
        when Time, ActiveSupport::TimeWithZone then from
        when DateTime then from.to_time
        when String then Time.parse(from)
        end
      },
      "date and time": ->(from, time = nil) {
        return if from.nil?
        if time
          return DateTime.new(from.year, from.month, from.day, time.hour, time.min, time.sec, time.respond_to?(:utc_offset) ? Rational(time.utc_offset, 86_400) : 0)
        end
        case from
        when DateTime, Time, ActiveSupport::TimeWithZone then from
        when Date then from.to_datetime
        when String then DateTime.parse(from)
        end
      },
      "duration": ->(from, to = nil) {
        return if from.nil?
        return from if from.is_a?(ActiveSupport::Duration)
        return (Date.parse(to.to_s) - Date.parse(from.to_s)).to_i.days if to
        ActiveSupport::Duration.parse(from)
      },
      "years and months duration": ->(from, to) {
        return if from.nil? || to.nil?
        months = (to.year * 12 + to.month) - (from.year * 12 + from.month)
        months -= 1 if months.positive? && to.day < from.day
        months += 1 if months.negative? && to.day > from.day
        ActiveSupport::Duration.build(0) + (months / 12).years + (months % 12).months
      },
      "now": ->() { Time.now },
      "today": ->() { Date.today },
      "day of week": ->(date) {
        return if date.nil?
        date.wday
      },
      "day of year": ->(date) {
        return if date.nil?
        date.yday
      },
      "week of year": ->(date) {
        return if date.nil?
        date.cweek
      },
      "month of year": ->(date) {
        return if date.nil?
        date.month
      },
    }.freeze
  end
end
