# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinConversionFunctionsTest
module FEEL
  describe "built-in conversion functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A date() function" do
      it "should convert String" do
        _(evaluate(" date(x) ", x: "2012-12-25")).must_equal Date.new(2012, 12, 25)
      end

      it "should convert Date-Time" do
        _(evaluate(' date( date and time("2012-12-25T11:00:00") ) ')).must_equal Date.new(2012, 12, 25)
        _(evaluate(' date( date and time("2012-12-25T11:00:00+01:00") ) ')).must_equal Date.new(2012, 12, 25)
      end

      it "should convert (year,month,day)" do
        _(evaluate(" date(2012, 12, 25) ")).must_equal Date.new(2012, 12, 25)
      end

      it "should return null if the date is not valid (not a leap year)" do
        _(evaluate(" date(x) ", x: "2023-02-29")).must_be_nil
        _(evaluate(" date(2023, 2, 29) ")).must_be_nil
      end

      it "should return null if the date is not valid (month without 31 days)" do
        _(evaluate(" date(x) ", x: "2023-06-31")).must_be_nil
        _(evaluate(" date(2023, 6, 31) ")).must_be_nil
      end
    end

    describe "A date and time() function" do
      it "should convert String" do
        _(evaluate(" date and time(x) ", x: "2012-12-24T23:59:00")).must_equal DateTime.new(2012, 12, 24, 23, 59, 0)
        _(evaluate(" date and time(x) ", x: "2012-12-24T23:59:00+01:00")).must_equal DateTime.new(2012, 12, 24, 23, 59, 0, "+01:00")
        result = evaluate(" date and time(x) ", x: "2012-12-24T23:59:00@Europe/Berlin")
        _(result).must_equal Time.find_zone!("Europe/Berlin").local(2012, 12, 24, 23, 59, 0)
        _(result.time_zone.name).must_equal "Europe/Berlin"
      end

      it "should convert (DateTime, Timezone)" do
        result = evaluate('date and time(@"2020-07-31T14:27:30@Europe/Berlin", "Z")')
        _(result).must_equal DateTime.new(2020, 7, 31, 12, 27, 30)
        _(result.utc_offset).must_equal 0

        result = evaluate('date and time(@"2020-07-31T14:27:30@Europe/Berlin", "America/Los_Angeles")')
        _(result).must_equal Time.find_zone!("America/Los_Angeles").local(2020, 7, 31, 5, 27, 30)
        _(result.time_zone.name).must_equal "America/Los_Angeles"

        result = evaluate('date and time(@"2020-07-31T14:27:30", "Z")')
        _(result).must_equal DateTime.new(2020, 7, 31, 14, 27, 30)
        _(result.utc_offset).must_equal 0
      end

      it "should convert (Date,Time)" do
        _(evaluate(' date and time(date("2012-12-24"),time("T23:59:00")) ')).must_equal DateTime.new(2012, 12, 24, 23, 59, 0)
        _(evaluate(' date and time(date("2012-12-24"),time("T23:59:00+01:00")) ')).must_equal DateTime.new(2012, 12, 24, 23, 59, 0, "+01:00")
      end

      it "should convert (DateTime,Time)" do
        _(evaluate(' date and time(date and time("2012-12-24T10:24:00"),time("T23:59:00")) ')).must_equal DateTime.new(2012, 12, 24, 23, 59, 0)
        _(evaluate(' date and time(date and time("2012-12-24T10:24:00"),time("T23:59:00+01:00")) ')).must_equal DateTime.new(2012, 12, 24, 23, 59, 0, "+01:00")
        _(evaluate(' date and time(date and time("2012-12-24T10:24:00+01:00"),time("T23:59:00")) ')).must_equal DateTime.new(2012, 12, 24, 23, 59, 0)
        _(evaluate(' date and time(date and time("2012-12-24T10:24:00+01:00"),time("T23:59:00+01:00")) ')).must_equal DateTime.new(2012, 12, 24, 23, 59, 0, "+01:00")
      end

      it "should return null if the date is not valid (not a leap year)" do
        _(evaluate(" date and time(x) ", x: "2023-02-29T10:00:00")).must_be_nil
        _(evaluate(" date and time(x) ", x: "2023-02-29T10:00:00+02:00")).must_be_nil
      end

      it "should return null if the date is not valid (month without 31 days)" do
        _(evaluate(" date and time(x) ", x: "2023-06-31T10:00:00")).must_be_nil
        _(evaluate(" date and time(x) ", x: "2023-06-31T10:00:00+02:00")).must_be_nil
      end

      it "should convert a string in ISO format with timezone ID" do
        result = evaluate(" date and time(x) ", x: "2023-06-14T14:55:00+02:00[Europe/Berlin]")
        _(result).must_equal Time.find_zone!("Europe/Berlin").local(2023, 6, 14, 14, 55, 0)
        _(result.time_zone.name).must_equal "Europe/Berlin"
      end
    end

    describe "A time() function" do
      # [hour, minute, second] of a local time, plus the UTC offset in seconds for a time with offset
      def time_parts(time, with_offset: false)
        parts = [time.hour, time.min, time.sec]
        with_offset ? parts + [time.utc_offset] : parts
      end

      it "should convert String" do
        _(time_parts(evaluate(" time(x) ", x: "23:59:00"))).must_equal [23, 59, 0]
        _(time_parts(evaluate(" time(x) ", x: "23:59:00+01:00"), with_offset: true)).must_equal [23, 59, 0, 3600]
        _(time_parts(evaluate(" time(x) ", x: "23:59:00@Europe/Paris"), with_offset: true)).must_equal [23, 59, 0, 3600]
      end

      it "should convert Date-Time" do
        _(time_parts(evaluate(' time( date and time("2012-12-25T11:00:00") ) '))).must_equal [11, 0, 0]
        _(time_parts(evaluate(' time( date and time("2012-12-25T11:00:00+01:00") ) '), with_offset: true)).must_equal [11, 0, 0, 3600]
      end

      it "should convert (hour,minute,second)" do
        _(time_parts(evaluate(" time(23, 59, 0) "))).must_equal [23, 59, 0]
      end

      it "should convert (hour,minute,second, offset)" do
        _(time_parts(evaluate(' time(14, 30, 0, duration("PT1H")) '), with_offset: true)).must_equal [14, 30, 0, 3600]
      end
    end

    describe "A number() function" do
      it "should convert String" do
        _(evaluate(' number("1500.5") ')).must_equal 1500.5
      end

      it "should convert String with Grouping Separator ' '" do
        _(evaluate(' number("1 500.5", " ") ')).must_equal 1500.5
      end

      it "should convert String with Grouping Separator ','" do
        _(evaluate(' number("1,500", ",") ')).must_equal 1500
      end

      it "should convert String with Grouping Separator '.'" do
        _(evaluate(' number("1.500", ".") ')).must_equal 1500
      end

      it "should convert String with Grouping ' ' and Decimal Separator '.'" do
        _(evaluate(' number("1 500.5", " ", ".") ')).must_equal 1500.5
      end

      it "should convert String with Grouping ' ' and Decimal Separator ','" do
        _(evaluate(' number("1 500,5", " ", ",") ')).must_equal 1500.5
      end

      it "should convert String with Grouping null and Decimal Separator ','" do
        _(evaluate(' number("1500,5", null, ",") ')).must_equal 1500.5
      end

      it "should convert String with Grouping '.' and Decimal null" do
        _(evaluate(' number("1.500", ".", null) ')).must_equal 1500
      end

      it "should be invoked with named parameter" do
        _(evaluate(' number(from: "1.500", grouping separator: ".", decimal separator: null) ')).must_equal 1500
      end

      it "should return null if the string is not a number" do
        _(evaluate(' number("x") ')).must_be_nil
        _(evaluate(' number("x", ".") ')).must_be_nil
        _(evaluate(' number("x", ".", ",") ')).must_be_nil
      end
    end

    describe "A string() function" do
      it "should convert Number" do
        _(evaluate(" string(1.1) ")).must_equal "1.1"
      end

      it "should convert a string" do
        _(evaluate(' string("hello") ')).must_equal "hello"
      end

      it "should convert Boolean" do
        _(evaluate(" string(true) ")).must_equal "true"
      end

      it "should convert Date" do
        _(evaluate(' string(date("2012-12-25")) ')).must_equal "2012-12-25"
      end

      it "should convert Time" do
        _(evaluate(' string(time("23:59:00")) ')).must_equal "23:59:00"
        _(evaluate(' string(time("23:59:00+01:00")) ')).must_equal "23:59:00+01:00"
      end

      it "should convert Date-Time" do
        _(evaluate(' string(date and time("2012-12-25T11:00:00")) ')).must_equal "2012-12-25T11:00:00"
        _(evaluate(' string(date and time("2012-12-25T11:00:00+02:00")) ')).must_equal "2012-12-25T11:00:00+02:00"
      end

      it "should convert zero-length days-time-duration" do
        _(evaluate(' string(@"-PT0S") ')).must_equal "P0D"
        _(evaluate(' string(@"P0D") ')).must_equal "P0D"
        _(evaluate(' string(@"PT0H") ')).must_equal "P0D"
        _(evaluate(' string(@"PT0H0M") ')).must_equal "P0D"
        _(evaluate(' string(@"PT0H0M0S") ')).must_equal "P0D"
        _(evaluate(' string(@"P0DT0H0M0S") ')).must_equal "P0D"
      end

      it "should convert negative days-time-duration" do
        _(evaluate(' string(@"-PT1S") ')).must_equal "-PT1S"
        _(evaluate(' string(@"-PT1H") ')).must_equal "-PT1H"
        _(evaluate(' string(@"-PT2M30S") ')).must_equal "-PT2M30S"
        _(evaluate(' string(@"-P1DT2H3M4S") ')).must_equal "-P1DT2H3M4S"
      end

      it "should convert days-time-duration" do
        _(evaluate(' string(@"PT1H") ')).must_equal "PT1H"
        _(evaluate(' string(@"PT2M30S") ')).must_equal "PT2M30S"
        _(evaluate(' string(@"P1DT2H3M4S") ')).must_equal "P1DT2H3M4S"
      end

      it "should convert zero-length years-months-duration" do
        _(evaluate(' string(@"P0Y") ')).must_equal "P0Y"
        _(evaluate(' string(@"-P0M") ')).must_equal "P0Y"
        _(evaluate(' string(@"P0Y0M") ')).must_equal "P0Y"
      end

      it "should convert negative years-months-duration" do
        _(evaluate(' string(@"-P1Y") ')).must_equal "-P1Y"
        _(evaluate(' string(@"-P5M") ')).must_equal "-P5M"
        _(evaluate(' string(@"-P3Y1M") ')).must_equal "-P3Y1M"
      end

      it "should convert years-months-duration" do
        _(evaluate(' string(@"P1Y") ')).must_equal "P1Y"
        _(evaluate(' string(@"P2M") ')).must_equal "P2M"
        _(evaluate(' string(@"P1Y2M") ')).must_equal "P1Y2M"
      end

      it "should return null if the argument is null" do
        _(evaluate(" string(null) ")).must_be_nil
      end

      it "should convert a list" do
        _(evaluate(" string([]) ")).must_equal "[]"
        _(evaluate(" string([1,2,3]) ")).must_equal "[1, 2, 3]"
      end

      it "should convert a context" do
        _(evaluate(" string({}) ")).must_equal "{}"
        _(evaluate(" string({a:1,b:2}) ")).must_equal "{a:1, b:2}"
      end

      # Not applicable: "convert a custom context" uses a Scala CustomValueMapper and a custom Context class
      # Not applicable: "convert a list containing a custom context" uses a Scala CustomValueMapper and a custom Context class
      # Not applicable: "convert a nested custom context" uses a Scala CustomValueMapper and a custom Context class
    end

    describe "A duration() function" do
      it "should convert day-time-String" do
        _(evaluate(" duration(x) ", x: "P2DT20H14M")).must_equal 2.days + 20.hours + 14.minutes
      end

      it "should convert day-time-String with negative duration" do
        _(evaluate(" duration(x) ", x: "-PT5M")).must_equal(-5.minutes)
        _(evaluate(" duration(x) ", x: "PT-5M")).must_equal(-5.minutes)
        _(evaluate(" duration(x) ", x: "P-1D")).must_equal(-1.day)
        _(evaluate(" duration(x) ", x: "PT-2H")).must_equal(-2.hours)
        _(evaluate(" duration(x) ", x: "PT-3M-4S")).must_equal(-3.minutes - 4.seconds)
      end

      it "should convert year-month-String" do
        _(evaluate(" duration(x) ", x: "P2Y4M")).must_equal 2.years + 4.months
      end

      it "should convert year-month-String with negative duration" do
        _(evaluate(" duration(x) ", x: "-P1Y2M")).must_equal(-1.year - 2.months)
        _(evaluate(" duration(x) ", x: "P-1Y")).must_equal(-1.year)
        _(evaluate(" duration(x) ", x: "P-2M")).must_equal(-2.months)
        _(evaluate(" duration(x) ", x: "P-1Y-2M")).must_equal(-1.year - 2.months)
      end
    end

    describe "A years and months duration(from,to) function" do
      it "should convert (Date,Date)" do
        _(evaluate(' years and months duration( date("2011-12-22"), date("2013-08-24") ) ')).must_equal 1.year + 8.months
        _(evaluate(' years and months duration( date and time("2011-12-22T10:00:00"), date and time("2013-08-24T10:00:00") ) ')).must_equal 1.year + 8.months
        _(evaluate(' years and months duration( date and time("2011-12-22T10:00:00+01:00"), date and time("2013-08-24T10:00:00+01:00") ) ')).must_equal 1.year + 8.months
      end
    end

    describe "A from json() function" do
      it "should convert a JSON object to a context" do
        _(evaluate(" from json(value) ", value: '{"a": 1, "b": 2}')).must_equal({ "a" => 1, "b" => 2 })
      end

      it "should convert a JSON array to a list" do
        _(evaluate(" from json(value) ", value: "[1, 2, 3]")).must_equal [1, 2, 3]
      end

      it "should convert a JSON null value" do
        _(evaluate(' from json("null") ')).must_be_nil
      end

      it "should convert a JSON number" do
        _(evaluate(" from json(value) ", value: "1")).must_equal 1
      end

      it "should convert a JSON string" do
        _(evaluate(" from json(value) ", value: '"a"')).must_equal "a"
        _(evaluate(" from json(value) ", value: '"2023-06-14"')).must_equal "2023-06-14"
        _(evaluate(" from json(value) ", value: '"14:55:00"')).must_equal "14:55:00"
        _(evaluate(" from json(value) ", value: '"2023-06-14T14:55:00"')).must_equal "2023-06-14T14:55:00"
        _(evaluate(" from json(value) ", value: '"P1Y"')).must_equal "P1Y"
        _(evaluate(" from json(value) ", value: '"PT2H"')).must_equal "PT2H"
      end

      it "should convert a JSON boolean" do
        _(evaluate(" from json(value) ", value: "true")).must_equal true
        _(evaluate(" from json(value) ", value: "false")).must_equal false
      end

      it "should return null if the JSON is invalid" do
        _(evaluate(" from json(value) ", value: "invalid")).must_be_nil
      end
    end

    describe "A to json() function" do
      it "should convert a string value" do
        _(evaluate(' to json("hello") ')).must_equal '"hello"'
      end

      it "should convert a number" do
        _(evaluate(" to json(42) ")).must_equal "42"
      end

      it "should convert a boolean" do
        _(evaluate(" to json(true) ")).must_equal "true"
      end

      it "should convert a list" do
        _(evaluate(' to json(["a","b","c"]) ')).must_equal '["a","b","c"]'
      end

      it "should convert a nested list" do
        _(evaluate(" to json([[1,2],3]) ")).must_equal "[[1,2],3]"
      end

      it "should convert a context/map" do
        _(evaluate(' to json({a: 1, b: "foo"}) ')).must_equal '{"a":1,"b":"foo"}'
      end

      it "should convert a nested context/map" do
        _(evaluate(' to json({person: {name: "Alice", age: 30}}) ')).must_equal '{"person":{"name":"Alice","age":30}}'
      end

      it "should convert null" do
        _(evaluate(" to json(null) ")).must_equal "null"
      end

      it "should convert a date" do
        _(evaluate(' to json(@"2023-06-14") ')).must_equal '"2023-06-14"'
      end

      it "should convert a time" do
        _(evaluate(' to json(@"14:55:00") ')).must_equal '"14:55:00"'
      end

      it "should convert a date and time" do
        _(evaluate(' to json(@"2023-06-14T14:55:00") ')).must_equal '"2023-06-14T14:55:00"'
      end

      it "should convert a day-time duration" do
        _(evaluate(' to json(@"PT2H30M") ')).must_equal '"PT2H30M"'
      end

      it "should convert a year-month duration" do
        _(evaluate(' to json(@"P1Y6M") ')).must_equal '"P1Y6M"'
      end

      # Adapted: durations are serialized in the FEEL format of string(), not
      # in the java.time format of feel-scala (e.g. "PT26H", "PT0S").
      it "should convert a duration like string()" do
        _(evaluate(' to json(@"PT26H") ')).must_equal '"P1DT2H"'
        _(evaluate(' to json(@"PT0S") ')).must_equal '"P0D"'
        _(evaluate(' to json(@"P0Y") ')).must_equal '"P0Y"'
        _(evaluate(' to json(@"-P1DT2H3M4S") ')).must_equal '"-P1DT2H3M4S"'
        _(evaluate(' to json(duration("P14M")) ')).must_equal '"P1Y2M"'
        _(evaluate(' to json({d: @"PT26H"}) ')).must_equal '{"d":"P1DT2H"}'

        %w[PT26H PT0S P0Y -P1DT2H3M4S P2D P1Y6M].each do |duration|
          _(evaluate(%( to json(@"#{duration}") ))).must_equal "\"#{evaluate(%( string(@"#{duration}") ))}\""
        end
      end

      it "should convert a time with offset" do
        _(evaluate(' to json(@"14:55:00+02:00") ')).must_equal '"14:55:00+02:00"'
      end

      it "should convert a time with timezone" do
        zoned = FEEL::ZonedTime.new(FEEL::LocalTime.from_seconds((14 * 3600) + (55 * 60)), 2 * 3600, "Europe/Berlin")
        _(evaluate(" to json(x) ", x: zoned)).must_equal '"14:55:00+02:00"'
      end

      it "should convert a date and time with offset" do
        _(evaluate(' to json(@"2023-06-14T14:55:00+02:00") ')).must_equal '"2023-06-14T14:55:00+02:00"'
      end

      it "should convert a date and time with timezone" do
        _(evaluate(' to json(@"2023-06-14T14:55:00@Europe/Berlin") ')).must_equal '"2023-06-14T14:55:00+02:00[Europe/Berlin]"'
      end

      it "should convert a function" do
        _(evaluate(" to json(function (a,b) a + b) ")).must_equal '"function(a, b)"'
      end

      it "should convert a range" do
        _(evaluate(" to json((1..10]) ")).must_equal '"(1..10]"'
      end
    end
  end
end
