# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterDateTimeExpressionTest
module FEEL
  describe "date, time and duration expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    it "A time should subtract from another time" do
      _(evaluate(' time("10:30:00") - time("09:00:00") ')).must_equal(FEEL::Duration.hours(1) + FEEL::Duration.minutes(30))

      _(evaluate(' time("09:00:00") - time("10:00:00") ')).must_equal(-FEEL::Duration.hours(1))

      _(evaluate(' time("12:00:00+01:00") - time("10:00:00+01:00") ')).must_equal FEEL::Duration.hours(2)
    end

    it "A time should compare with '='" do
      _(evaluate(' time("10:00:00") = time("10:00:00") ')).must_equal true
      _(evaluate(' time("10:00:00") = time("10:30:00") ')).must_equal false

      _(evaluate(' time("10:00:00+01:00") = time("10:30:00+01:00") ')).must_equal false
      _(evaluate(' time("10:00:00+01:00") = time("10:00:00+02:00") ')).must_equal false
      _(evaluate(' time("10:00:00+01:00") = time("10:00:00+01:00") ')).must_equal true
    end

    it "A time should compare with '!='" do
      _(evaluate(' time("10:00:00") != time("10:00:00") ')).must_equal false
      _(evaluate(' time("10:00:00") != time("22:00:00") ')).must_equal true

      _(evaluate(' time("10:00:00+01:00") != time("10:00:00+01:00") ')).must_equal false
      _(evaluate(' time("10:00:00+01:00") != time("22:00:00+01:00") ')).must_equal true
    end

    it "A time should compare with '<'" do
      _(evaluate(' time("10:00:00") < time("11:00:00") ')).must_equal true
      _(evaluate(' time("10:00:00") < time("10:00:00") ')).must_equal false

      _(evaluate(' time("10:00:00+01:00") < time("11:00:00+01:00") ')).must_equal true
      _(evaluate(' time("10:00:00+01:00") < time("10:00:00+01:00") ')).must_equal false
    end

    it "A time should compare with '<='" do
      _(evaluate(' time("10:00:00") <= time("10:00:00") ')).must_equal true
      _(evaluate(' time("10:00:01") <= time("10:00:00") ')).must_equal false

      _(evaluate(' time("10:00:00+01:00") <= time("10:00:00+01:00") ')).must_equal true
      _(evaluate(' time("11:00:00+01:00") <= time("10:00:00+01:00") ')).must_equal false
    end

    it "A time should compare with '>'" do
      _(evaluate(' time("11:00:00") > time("11:00:00") ')).must_equal false
      _(evaluate(' time("10:15:00") > time("10:00:00") ')).must_equal true

      _(evaluate(' time("11:00:00+01:00") > time("11:00:00+01:00") ')).must_equal false
      _(evaluate(' time("10:15:00+01:00") > time("10:00:00+01:00") ')).must_equal true
    end

    it "A time should compare with '>='" do
      _(evaluate(' time("11:00:00") >= time("11:00:00") ')).must_equal true
      _(evaluate(' time("09:00:00") >= time("11:15:00") ')).must_equal false

      _(evaluate(' time("11:00:00+01:00") >= time("11:00:00+01:00") ')).must_equal true
      _(evaluate(' time("09:00:00+01:00") >= time("11:15:00+01:00") ')).must_equal false
    end

    it "A time should compare with 'between _ and _'" do
      _(evaluate(' time("08:30:00") between time("08:00:00") and time("10:00:00") ')).must_equal true
      _(evaluate(' time("08:30:00") between time("09:00:00") and time("10:00:00") ')).must_equal false

      _(evaluate(' time("08:30:00+01:00") between time("08:00:00+01:00") and time("10:00:00+01:00") ')).must_equal true
      _(evaluate(' time("08:30:00+01:00") between time("09:00:00+01:00") and time("10:00:00+01:00") ')).must_equal false
    end

    it "A date should subtract from another date" do
      _(evaluate(' date("2012-12-25") - date("2012-12-24") ')).must_equal FEEL::Duration.days(1)

      _(evaluate(' date("2012-12-24") - date("2012-12-25") ')).must_equal(-FEEL::Duration.days(1))

      _(evaluate(' date("2013-02-25") - date("2012-12-24") ')).must_equal FEEL::Duration.days(63)
    end

    it "A date should subtract date from date as string" do
      _(evaluate(' string(date("2020-04-07") - date("2020-04-01")) ')).must_equal "P6D"
    end

    it "A date should compare with '='" do
      _(evaluate(' date("2017-01-10") = date("2017-01-10") ')).must_equal true
      _(evaluate(' date("2017-01-10") = date("2017-01-11") ')).must_equal false
    end

    it "A date should compare with '!='" do
      _(evaluate(' date("2017-01-10") != date("2017-01-10") ')).must_equal false
      _(evaluate(' date("2017-01-10") != date("2017-02-10") ')).must_equal true
    end

    it "A date should compare with '<'" do
      _(evaluate(' date("2016-01-10") < date("2017-01-10") ')).must_equal true
      _(evaluate(' date("2017-01-10") < date("2017-01-10") ')).must_equal false
    end

    it "A date should compare with '<='" do
      _(evaluate(' date("2017-01-10") <= date("2017-01-10") ')).must_equal true
      _(evaluate(' date("2017-01-20") <= date("2017-01-10") ')).must_equal false
    end

    it "A date should compare with '>'" do
      _(evaluate(' date("2017-01-10") > date("2017-01-10") ')).must_equal false
      _(evaluate(' date("2017-02-17") > date("2017-01-10") ')).must_equal true
    end

    it "A date should compare with '>='" do
      _(evaluate(' date("2017-01-10") >= date("2017-01-10") ')).must_equal true
      _(evaluate(' date("2017-01-10") >= date("2018-01-10") ')).must_equal false
    end

    it "A date should compare with 'between _ and _'" do
      _(evaluate(' date("2017-01-10") between date("2017-01-01") and date("2018-01-10") ')).must_equal true
      _(evaluate(' date("2017-01-10") between date("2017-02-01") and date("2017-03-01") ')).must_equal false
    end

    it "A date-time should subtract from another date-time" do
      _(evaluate(' date and time("2017-01-10T10:30:00") - date and time("2017-01-01T10:00:00") ')).must_equal(FEEL::Duration.days(9) + FEEL::Duration.minutes(30))
      _(evaluate(' date and time("2017-01-10T10:00:00") - date and time("2017-01-10T10:30:00") ')).must_equal(-FEEL::Duration.minutes(30))

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") - date and time("2017-01-01T10:00:00+01:00") ')).must_equal(FEEL::Duration.days(9) + FEEL::Duration.minutes(30))
      _(evaluate(' date and time("2017-01-10T10:00:00+01:00") - date and time("2017-01-10T10:30:00+01:00") ')).must_equal(-FEEL::Duration.minutes(30))
    end

    it "A date-time should compare with '='" do
      _(evaluate(' date and time("2017-01-10T10:30:00") = date and time("2017-01-10T10:30:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00") = date and time("2017-01-10T14:00:00") ')).must_equal false

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") = date and time("2017-01-10T10:30:00+01:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") = date and time("2017-01-10T14:00:00+01:00") ')).must_equal false
    end

    it "A date-time should compare with '!='" do
      _(evaluate(' date and time("2017-01-10T10:30:00") != date and time("2017-01-10T10:30:00") ')).must_equal false
      _(evaluate(' date and time("2017-01-10T10:30:00") != date and time("2017-01-11T10:30:00") ')).must_equal true

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") != date and time("2017-01-10T10:30:00+01:00") ')).must_equal false
      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") != date and time("2017-01-11T10:30:00+01:00") ')).must_equal true
    end

    it "A date-time should compare with '<'" do
      _(evaluate(' date and time("2017-01-10T10:30:00") < date and time("2017-02-10T10:00:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00") < date and time("2017-01-10T10:30:00") ')).must_equal false

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") < date and time("2017-02-10T10:00:00+01:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") < date and time("2017-01-10T10:30:00+01:00") ')).must_equal false
    end

    it "A date-time should compare with '<='" do
      _(evaluate(' date and time("2017-01-10T10:30:00") <= date and time("2017-01-10T10:30:00") ')).must_equal true
      _(evaluate(' date and time("2017-02-10T10:00:00") <= date and time("2017-01-10T10:30:00") ')).must_equal false

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") <= date and time("2017-01-10T10:30:00+01:00") ')).must_equal true
      _(evaluate(' date and time("2017-02-10T10:00:00+01:00") <= date and time("2017-01-10T10:30:00+01:00") ')).must_equal false
    end

    it "A date-time should compare with '>'" do
      _(evaluate(' date and time("2017-01-10T10:30:00") > date and time("2017-01-10T10:30:00") ')).must_equal false
      _(evaluate(' date and time("2018-01-10T10:30:00") > date and time("2017-01-10T10:30:00") ')).must_equal true

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") > date and time("2017-01-10T10:30:00+01:00") ')).must_equal false
      _(evaluate(' date and time("2018-01-10T10:30:00+01:00") > date and time("2017-01-10T10:30:00+01:00") ')).must_equal true
    end

    it "A date-time should compare with '>='" do
      _(evaluate(' date and time("2017-01-10T10:30:00") >= date and time("2017-01-10T10:30:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00") >= date and time("2017-01-10T10:30:01") ')).must_equal false

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") >= date and time("2017-01-10T10:30:00+01:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") >= date and time("2017-01-10T10:30:01+01:00") ')).must_equal false
    end

    it "A date-time should compare with 'between _ and _'" do
      _(evaluate(' date and time("2017-01-10T10:30:00") between date and time("2017-01-10T09:00:00") and date and time("2017-01-10T14:00:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00") between date and time("2017-01-10T11:00:00") and date and time("2017-01-11T08:00:00") ')).must_equal false

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") between date and time("2017-01-10T09:00:00+01:00") and date and time("2017-01-10T14:00:00+01:00") ')).must_equal true
      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") between date and time("2017-01-10T11:00:00+01:00") and date and time("2017-01-11T08:00:00+01:00") ')).must_equal false
    end

    it "A year-month-duration should add to year-month-duration" do
      _(evaluate(' duration("P2M") + duration("P3M") ')).must_equal FEEL::Duration.months(5)
      _(evaluate(' duration("P1Y") + duration("P6M") ')).must_equal(FEEL::Duration.years(1) + FEEL::Duration.months(6))
    end

    it "A year-month-duration should add to date-time" do
      _(evaluate(' duration("P1M") + date and time("2017-01-10T10:30:00") ')).must_equal LocalDateTime.new(2017, 2, 10, 10, 30, 0)
      _(evaluate(' date and time("2017-01-10T10:30:00") + duration("P1Y") ')).must_equal LocalDateTime.new(2018, 1, 10, 10, 30, 0)

      _(evaluate(' duration("P1M") + date and time("2017-01-10T10:30:00+01:00") ')).must_equal Time.new(2017, 2, 10, 10, 30, 0, "+01:00")
      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") + duration("P1Y") ')).must_equal Time.new(2018, 1, 10, 10, 30, 0, "+01:00")
    end

    it "A year-month-duration should add to date" do
      _(evaluate(' duration("P1M") + date("2017-01-10") ')).must_equal Date.new(2017, 2, 10)
      _(evaluate(' date("2017-01-10") + duration("P1Y") ')).must_equal Date.new(2018, 1, 10)
    end

    it "A year-month-duration should subtract from year-month-duration" do
      _(evaluate(' duration("P1Y") - duration("P3M") ')).must_equal FEEL::Duration.months(9)
      _(evaluate(' duration("P5M") - duration("P6M") ')).must_equal(-FEEL::Duration.months(1))
    end

    it "A year-month-duration should subtract from date-time" do
      _(evaluate(' date and time("2017-01-10T10:30:00") - duration("P1M") ')).must_equal LocalDateTime.new(2016, 12, 10, 10, 30, 0)

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") - duration("P1M") ')).must_equal Time.new(2016, 12, 10, 10, 30, 0, "+01:00")
    end

    it "A year-month-duration should subtract from date" do
      _(evaluate(' date("2017-01-10") - duration("P1M") ')).must_equal Date.new(2016, 12, 10)

      _(evaluate(' date("2017-01-10") - duration("P1Y") ')).must_equal Date.new(2016, 1, 10)

      _(evaluate(' date("2017-01-10") - duration("P1Y1M") ')).must_equal Date.new(2015, 12, 10)
    end

    it "A year-month-duration should multiply by '3'" do
      _(evaluate(' duration("P1M") * 3 ')).must_equal FEEL::Duration.months(3)
      _(evaluate(' 3 * duration("P2Y") ')).must_equal FEEL::Duration.years(6)
    end

    it "A year-month-duration should divide by '4'" do
      _(evaluate(' duration("P1Y") / 2 ')).must_equal FEEL::Duration.months(6)
    end

    it "A year-month-duration should divide by duration" do
      _(evaluate(' duration("P1Y") / duration("P1M") ')).must_equal 12
    end

    it "A year-month-duration should divide by zero duration" do
      _(evaluate(' duration("P1Y") / duration("P0M") ')).must_be_nil
    end

    it "A year-month-duration should compare with '='" do
      _(evaluate(' duration("P2M") = duration("P2M") ')).must_equal true
      _(evaluate(' duration("P2M") = duration("P4M") ')).must_equal false
    end

    it "A year-month-duration should compare with '!='" do
      _(evaluate(' duration("P2M") != duration("P2M") ')).must_equal false
      _(evaluate(' duration("P2M") != duration("P1Y") ')).must_equal true
    end

    it "A year-month-duration should compare with '<'" do
      _(evaluate(' duration("P2M") < duration("P3M") ')).must_equal true
      _(evaluate(' duration("P2M") < duration("P2M") ')).must_equal false
    end

    it "A year-month-duration should compare with '<='" do
      _(evaluate(' duration("P2M") <= duration("P2M") ')).must_equal true
      _(evaluate(' duration("P1Y2M") <= duration("P2M") ')).must_equal false
    end

    it "A year-month-duration should compare with '>'" do
      _(evaluate(' duration("P2M") > duration("P2M") ')).must_equal false
      _(evaluate(' duration("P2M") > duration("P1M") ')).must_equal true
    end

    it "A year-month-duration should compare with '>='" do
      _(evaluate(' duration("P2M") >= duration("P2M") ')).must_equal true
      _(evaluate(' duration("P2M") >= duration("P5M") ')).must_equal false
    end

    it "A year-month-duration should compare with 'between _ and _'" do
      _(evaluate(' duration("P3M") between duration("P2M") and duration("P6M") ')).must_equal true
      _(evaluate(' duration("P1Y") between duration("P2M") and duration("P6M") ')).must_equal false
    end

    it "A day-time-duration should add to day-time-duration" do
      _(evaluate(' duration("PT4H") + duration("PT2H") ')).must_equal FEEL::Duration.hours(6)
      _(evaluate(' duration("P1D") + duration("PT6H") ')).must_equal(FEEL::Duration.days(1) + FEEL::Duration.hours(6))
    end

    it "A day-time-duration should add to date-time" do
      _(evaluate(' duration("PT1H") + date and time("2017-01-10T10:30:00") ')).must_equal LocalDateTime.new(2017, 1, 10, 11, 30, 0)
      _(evaluate(' date and time("2017-01-10T10:30:00") + duration("P1D") ')).must_equal LocalDateTime.new(2017, 1, 11, 10, 30, 0)

      _(evaluate(' duration("PT1H") + date and time("2017-01-10T10:30:00+01:00") ')).must_equal Time.new(2017, 1, 10, 11, 30, 0, "+01:00")
      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") + duration("P1D") ')).must_equal Time.new(2017, 1, 11, 10, 30, 0, "+01:00")
    end

    it "A day-time-duration should add to date" do
      _(evaluate(' duration("PT1H") + date("2017-01-10") ')).must_equal Date.new(2017, 1, 10)
      _(evaluate(' duration("P1D") + date("2017-01-10") ')).must_equal Date.new(2017, 1, 11)
      _(evaluate(' date("2017-01-10") + duration("PT1M") ')).must_equal Date.new(2017, 1, 10)
      _(evaluate(' date("2017-01-10") + duration("P1D") ')).must_equal Date.new(2017, 1, 11)
    end

    it "A day-time-duration should add to time" do
      _(evaluate(' duration("PT1H") + time("10:30:00") ')).must_equal LocalTime.new(11, 30, 0)
      _(evaluate(' time("10:30:00") + duration("P1D") ')).must_equal LocalTime.new(10, 30, 0)

      _(evaluate(' duration("PT1H") + time("10:30:00+01:00") ')).must_equal ZonedTime.new(LocalTime.new(11, 30, 0), 3600)
      _(evaluate(' time("10:30:00+01:00") + duration("P1D") ')).must_equal ZonedTime.new(LocalTime.new(10, 30, 0), 3600)
    end

    it "A day-time-duration should subtract from day-time-duration" do
      _(evaluate(' duration("PT6H") - duration("PT2H") ')).must_equal FEEL::Duration.hours(4)
      _(evaluate(' duration("PT22H") - duration("P1D") ')).must_equal(-FEEL::Duration.hours(2))
    end

    it "A day-time-duration should subtract from date-time" do
      _(evaluate(' date and time("2017-01-10T10:30:00") - duration("PT1H") ')).must_equal LocalDateTime.new(2017, 1, 10, 9, 30, 0)

      _(evaluate(' date and time("2017-01-10T10:30:00+01:00") - duration("PT1H") ')).must_equal Time.new(2017, 1, 10, 9, 30, 0, "+01:00")
    end

    it "A day-time-duration should subtract from date" do
      _(evaluate(' date("2017-01-10") - duration("PT1H") ')).must_equal Date.new(2017, 1, 9)

      _(evaluate(' date("2017-01-10") - duration("P1DT1H") ')).must_equal Date.new(2017, 1, 8)
    end

    it "A day-time-duration should subtract from time" do
      _(evaluate(' time("10:30:00") - duration("PT1H") ')).must_equal LocalTime.new(9, 30, 0)

      _(evaluate(' time("10:30:00+01:00") - duration("PT1H") ')).must_equal ZonedTime.new(LocalTime.new(9, 30, 0), 3600)
    end

    it "A day-time-duration should multiply by '3'" do
      _(evaluate(' duration("PT2H") * 3 ')).must_equal FEEL::Duration.hours(6)
      _(evaluate(' 3 * duration("P1D") ')).must_equal FEEL::Duration.days(3)
    end

    it "A day-time-duration should divide by '4'" do
      _(evaluate(' duration("P1D") / 4 ')).must_equal FEEL::Duration.hours(6)
    end

    it "A day-time-duration should divide by duration" do
      _(evaluate(' duration("P1D") / duration("PT1H") ')).must_equal 24
    end

    it "A day-time-duration should divide by zero duration" do
      _(evaluate(' duration("P1D") / duration("PT0H") ')).must_be_nil
    end

    it "A day-time-duration should compare with '='" do
      _(evaluate(' duration("PT6H") = duration("PT6H") ')).must_equal true
      _(evaluate(' duration("PT6H") = duration("PT2H") ')).must_equal false
    end

    it "A day-time-duration should compare with '!='" do
      _(evaluate(' duration("PT6H") != duration("PT6H") ')).must_equal false
      _(evaluate(' duration("PT6H") != duration("P1D") ')).must_equal true
    end

    it "A day-time-duration should compare with '<'" do
      _(evaluate(' duration("PT6H") < duration("PT12H") ')).must_equal true
      _(evaluate(' duration("PT6H") < duration("PT6H") ')).must_equal false
    end

    it "A day-time-duration should compare with '<='" do
      _(evaluate(' duration("PT6H") <= duration("PT6H") ')).must_equal true
      _(evaluate(' duration("PT6H") <= duration("PT1H") ')).must_equal false
    end

    it "A day-time-duration should compare with '>'" do
      _(evaluate(' duration("PT6H") > duration("PT6H") ')).must_equal false
      _(evaluate(' duration("P1D") > duration("PT6H") ')).must_equal true
    end

    it "A day-time-duration should compare with '>='" do
      _(evaluate(' duration("PT6H") >= duration("PT6H") ')).must_equal true
      _(evaluate(' duration("PT6H") >= duration("PT6H1M") ')).must_equal false
    end

    it "A day-time-duration should compare with 'between _ and _'" do
      _(evaluate(' duration("PT8H") between duration("PT6H") and duration("PT12H") ')).must_equal true
      _(evaluate(' duration("PT2H") between duration("PT6H") and duration("PT12H") ')).must_equal false
    end

    # Not in feel-scala, which truncates the number to an integer (intValue)
    # and divides day-time durations with millisecond precision. Following
    # XPath (op:multiply/divide-dayTimeDuration and -yearMonthDuration), as
    # referenced by the DMN spec: day-time durations are exact (truncated to
    # nanoseconds), year-month durations are rounded to the nearest month.
    describe "duration multiplication and division by a number (spec)" do
      it "should divide a day-time-duration exactly" do
        _(evaluate(' string(@"PT1S" / 3) ')).must_equal "PT0.333333333S"
        _(evaluate(' string(@"-PT1S" / 3) ')).must_equal "-PT0.333333333S"
        _(evaluate(' string(@"PT10S" / 4) ')).must_equal "PT2.5S"
        _(evaluate(' string(@"P1D" / 7) ')).must_equal "PT3H25M42.857142857S"
        _(evaluate(' @"PT1S" / 0.5 ')).must_equal FEEL::Duration.seconds(2)
        _(evaluate(' @"PT1S" / 0 ')).must_be_nil
      end

      it "should multiply a day-time-duration by a decimal" do
        _(evaluate(' string(@"PT1S" * 1.5) ')).must_equal "PT1.5S"
        _(evaluate(' string(1.5 * @"PT1S") ')).must_equal "PT1.5S"
        _(evaluate(' string(@"PT1S" * 0.1) ')).must_equal "PT0.1S"
        _(evaluate(' @"PT1H" * 2.5 = @"PT2H30M" ')).must_equal true
      end

      it "should round a year-month-duration to the nearest month" do
        _(evaluate(' string(@"P1Y" * 1.5) ')).must_equal "P1Y6M"
        _(evaluate(' string(@"P1Y" / 5) ')).must_equal "P2M"
        _(evaluate(' string(@"P1Y" / 8) ')).must_equal "P2M"
        _(evaluate(' string(@"P1M" * 0.5) ')).must_equal "P1M"
        _(evaluate(' string(@"P1M" * 0.4) ')).must_equal "P0Y"
        _(evaluate(' string(@"-P1M" * 0.5) ')).must_equal "P0Y"
        _(evaluate(' @"P1Y" / 0 ')).must_be_nil
      end
    end
  end
end
