# frozen_string_literal: true

# Values of ActiveSupport (used by Rails applications) are accepted as input.
# Runs in its own process: `rake test:interop`.
ENV["FEEL_INTEROP"] = "1"

require "active_support"
require "active_support/time"
require "active_support/core_ext/object/json"
require "active_support/core_ext/hash/indifferent_access"
require "test_helper"

module FEEL
  describe "ActiveSupport interoperability" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    after do
      Time.zone = nil
    end

    describe :durations do
      it "should accept ActiveSupport durations as input" do
        _(evaluate("x", x: 3.days)).must_equal Duration.days(3)
        _(evaluate("x", x: 2.years + 3.months)).must_equal Duration.months(27)
        _(evaluate("x + duration(\"PT1H\")", x: 90.minutes)).must_equal Duration.minutes(150)
        _(evaluate('date("2020-01-31") + x', x: 1.month)).must_equal Date.new(2020, 2, 29)
        _(evaluate("x * 2", x: 1.5.hours)).must_equal Duration.hours(3)
        _(evaluate("x instance of days and time duration", x: 1.day)).must_equal true
        _(evaluate("x instance of number", x: 1.day)).must_equal false
        _(evaluate("string(x)", x: 26.hours)).must_equal "P1DT2H"
        _(evaluate("abs(x)", x: -2.days)).must_equal Duration.days(2)
        _(evaluate("-x", x: 2.days)).must_equal Duration.days(-2)
        _(FEEL.test(3.days, 'duration("P3D")')).must_equal true
      end

      it "should convert durations that mix months and days to seconds" do
        _(evaluate("x", x: 1.month + 2.days).kind).must_equal :days_time_duration
      end

      it "should convert FEEL durations to ActiveSupport durations" do
        _(Duration.parse("P1Y2M").to_active_support).must_equal 1.year + 2.months
        _(Duration.parse("-PT1H30M").to_active_support).must_equal(-90.minutes)
      end
    end

    describe :date_times do
      it "should accept TimeWithZone values and keep the zone" do
        time = Time.find_zone!("Europe/Berlin").local(2020, 7, 1, 10, 30, 0)
        result = evaluate("x", x: time)
        _(result).must_be_instance_of Time
        _(result.zone.identifier).must_equal "Europe/Berlin"
        _(evaluate("string(x)", x: time)).must_equal "2020-07-01T10:30:00@Europe/Berlin"
        _(evaluate('x + duration("P1M")', x: time)).must_equal Time.find_zone!("Europe/Berlin").local(2020, 8, 1, 10, 30, 0)
        _(evaluate('x > date and time("2020-07-01T08:00:00Z")', x: time)).must_equal true
        _(evaluate("x.timezone", x: time)).must_equal "Europe/Berlin"
      end

      it "should use Time.zone for now() and today()" do
        Time.zone = "Asia/Tokyo"
        _(evaluate("now()").zone.identifier).must_equal "Asia/Tokyo"
        FEEL.config.time_zone = "America/New_York"
        _(evaluate("now()").zone.identifier).must_equal "America/New_York"
      end
    end

    describe :hashes do
      it "should accept HashWithIndifferentAccess variables and functions" do
        _(evaluate("a.b + 1", { a: { b: 1 } }.with_indifferent_access)).must_equal 2
        _(evaluate('get value(context, ["x", "y"])', context: { x: { y: 1 } }.with_indifferent_access)).must_equal 1
        _(evaluate("{a:1, b:a+1}", { "a" => 0 }.with_indifferent_access)).must_equal({ "a" => 1, "b" => 2 })
        FEEL.config.functions = { "twice" => ->(x) { x * 2 } }.with_indifferent_access
        _(evaluate("twice(2)")).must_equal 4
      end
    end

    describe :json do
      it "should serialize FEEL values with ActiveSupport JSON" do
        value = evaluate('{t: time("10:30:00"), d: duration("P1Y2M"), l: date and time("2020-01-01T10:30:00")}')
        _(value.to_json).must_equal '{"t":"10:30:00","d":"P1Y2M","l":"2020-01-01T10:30:00"}'
      end

      it "should serialize ActiveSupport values with their FEEL types" do
        time = Time.find_zone!("Europe/Berlin").local(2020, 7, 1, 10, 30, 0)
        restored = FEEL.deserialize(FEEL.serialize({ "at" => time, "wait" => 3.days }).to_json)
        _(restored["at"]).must_equal time
        _(restored["at"].zone.identifier).must_equal "Europe/Berlin"
        _(restored["wait"]).must_equal Duration.days(3)
      end
    end
  end
end
