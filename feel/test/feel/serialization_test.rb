# frozen_string_literal: true

require "test_helper"

module FEEL
  describe "serialization" do
    VALUES = {
      "date" => 'date("2020-01-01")',
      "local time" => 'time("10:30:00")',
      "local time with fraction" => 'time("10:30:00.125")',
      "time with offset" => 'time("10:30:00+02:00")',
      "time with zone" => 'time("10:30:00@Europe/Paris")',
      "local date and time" => 'date and time("2020-01-01T10:30:00.5")',
      "date and time with offset" => 'date and time("2020-01-01T10:30:00+02:00")',
      "date and time in UTC" => 'date and time("2020-01-01T10:30:00Z")',
      "date and time with zone" => 'date and time("2020-07-01T10:30:00@Europe/Berlin")',
      "date and time in a DST overlap (first)" => 'date and time("2020-10-25T02:30:00+02:00[Europe/Berlin]")',
      "date and time in a DST overlap (second)" => 'date and time("2020-10-25T02:30:00+01:00[Europe/Berlin]")',
      "years and months duration" => 'duration("-P1Y2M")',
      "zero years and months duration" => 'duration("P0Y")',
      "days and time duration" => 'duration("P1DT2H3M4.5S")',
      "zero days and time duration" => 'duration("P0D")',
      "number" => "1.5",
      "integer" => "42",
      "string" => '"text"',
      "boolean" => "true",
      "null" => "null",
      "list" => '[1, "a", date("2020-01-01"), [duration("P1D")]]',
      "context" => '{a: 1, b: {c: date("2020-01-01"), d: [time("10:00:00")]}}',
    }.freeze

    def round_trip(value)
      FEEL.deserialize(JSON.generate(FEEL.serialize(value)))
    end

    describe :serialize do
      VALUES.each do |name, expression|
        it "should restore a #{name}" do
          value = FEEL.evaluate(expression)
          restored = round_trip(value)
          value.nil? ? _(restored).must_be_nil : _(restored).must_equal(value)
          _(restored.class).must_equal value.class
          next if value.nil?

          _(FEEL.evaluate("string(x)", variables: { x: restored })).must_equal FEEL.evaluate("string(#{expression})")
        end
      end

      it "should keep the zone of times and date-times" do
        _(round_trip(FEEL.evaluate('time("10:30:00@Europe/Paris")')).zone).must_equal "Europe/Paris"
        restored = round_trip(FEEL.evaluate('date and time("2020-07-01T10:30:00@Europe/Berlin")'))
        _(restored.zone.identifier).must_equal "Europe/Berlin"
        _(restored.utc_offset).must_equal 7200
      end

      it "should keep the instant in a DST overlap" do
        first = round_trip(FEEL.evaluate('date and time("2020-10-25T02:30:00+02:00[Europe/Berlin]")'))
        second = round_trip(FEEL.evaluate('date and time("2020-10-25T02:30:00+01:00[Europe/Berlin]")'))
        _(second - first).must_equal 3600
      end

      it "should tag values that JSON can't represent" do
        _(FEEL.serialize(Date.new(2020, 1, 1))).must_equal({ "$feel" => "date", "value" => "2020-01-01" })
        _(FEEL.serialize(Duration.hours(26))).must_equal({ "$feel" => "duration", "value" => "P1DT2H" })
        _(FEEL.serialize(FEEL.evaluate('time("10:30:00@Europe/Paris")')))
          .must_equal({ "$feel" => "time", "value" => "10:30:00+01:00", "zone" => "Europe/Paris" })
        _(FEEL.serialize({ a: [1, nil, "x"] })).must_equal({ "a" => [1, nil, "x"] })
      end

      it "should escape contexts with the tag key" do
        value = { "$feel" => "date", "value" => "not a date" }
        _(FEEL.serialize(value)).must_equal({ "$feel" => "context", "value" => value })
        _(round_trip(value)).must_equal value
      end

      it "should serialize ranges" do
        range = Range.build(Date.new(2020, 1, 1), Date.new(2020, 12, 31), true, false)
        restored = round_trip(range)
        _(restored).must_equal range
        _(restored.start).must_equal Date.new(2020, 1, 1)
      end

      it "should convert other Ruby temporal values" do
        _(round_trip(DateTime.new(2020, 1, 1, 10, 30, 0, "+02:00"))).must_equal Time.new(2020, 1, 1, 10, 30, 0, "+02:00")
      end

      it "should fail for functions and unknown objects" do
        _ { FEEL.serialize(FEEL.evaluate("function(x) x")) }.must_raise SerializationError
        _ { FEEL.serialize(->(x) { x }) }.must_raise SerializationError
        _ { FEEL.serialize(Object.new) }.must_raise SerializationError
      end

      it "should fail for invalid tagged values" do
        _ { FEEL.deserialize({ "$feel" => "date", "value" => "2020-02-30" }) }.must_raise SerializationError
        _ { FEEL.deserialize({ "$feel" => "unknown", "value" => "x" }) }.must_raise SerializationError
      end
    end

    describe :evaluate do
      it "should evaluate expressions with deserialized variables" do
        first = FEEL.evaluate('{due: date("2020-01-31"), wait: duration("P1M"), at: date and time("2020-01-01T10:00:00@Europe/Berlin")}')
        variables = FEEL.deserialize(JSON.generate(FEEL.serialize(first)))
        _(FEEL.evaluate("due + wait", variables: variables)).must_equal Date.new(2020, 2, 29)
        _(FEEL.evaluate("string(at + duration(\"PT1H\"))", variables: variables)).must_equal "2020-01-01T11:00:00@Europe/Berlin"
        _(FEEL.evaluate("due > date(\"2020-01-01\")", variables: variables)).must_equal true
      end

      it "should evaluate expressions with the results of other expressions" do
        first = FEEL.evaluate('{due: date("2020-01-31"), wait: duration("P1M")}')
        _(FEEL.evaluate("due + wait", variables: first)).must_equal Date.new(2020, 2, 29)
      end
    end

    describe :as_json do
      it "should give ISO 8601 strings for temporal values" do
        value = FEEL.evaluate('{d: date("2020-01-01"), t: time("10:30:00"), o: date and time("2020-01-01T10:30:00+02:00"), ' \
                              'z: date and time("2020-07-01T10:30:00@Europe/Berlin"), p: duration("P1Y2M"), s: duration("PT90M"), n: 1.5}')
        _(FEEL.as_json(value)).must_equal({
          "d" => "2020-01-01", "t" => "10:30:00", "o" => "2020-01-01T10:30:00+02:00",
          "z" => "2020-07-01T10:30:00+02:00", "p" => "P1Y2M", "s" => "PT1H30M", "n" => 1.5,
        })
        _(FEEL.to_json(value)).must_equal JSON.generate(FEEL.as_json(value))
      end

      it "should be the same as the FEEL function to json()" do
        VALUES.each_value do |expression|
          _(FEEL.to_json(FEEL.evaluate(expression))).must_equal FEEL.evaluate("to json(#{expression})")
        end
      end

      it "should be used by to_json of the FEEL value classes" do
        _(FEEL.evaluate('time("10:30:00")').to_json).must_equal '"10:30:00"'
        _(FEEL.evaluate('time("10:30:00+02:00")').to_json).must_equal '"10:30:00+02:00"'
        _(FEEL.evaluate('date and time("2020-01-01T10:30:00")').to_json).must_equal '"2020-01-01T10:30:00"'
        _(FEEL.evaluate('duration("P1Y2M")').to_json).must_equal '"P1Y2M"'
        _(JSON.generate([Duration.days(1), FEEL.evaluate('time("10:30:00")')])).must_equal '["P1D","10:30:00"]'
      end
    end
  end
end
