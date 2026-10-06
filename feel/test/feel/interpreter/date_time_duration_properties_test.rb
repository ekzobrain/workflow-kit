# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: DateTimeDurationPropertiesTest
module FEEL
  describe "date, time and duration properties" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    # A date

    it "A date should has a year property" do
      _(evaluate(' date("2017-03-10").year ')).must_equal 2017
    end

    it "A date should has a month property" do
      _(evaluate(' date("2017-03-10").month ')).must_equal 3
    end

    it "A date should has a day property" do
      _(evaluate(' date("2017-03-10").day ')).must_equal 10
    end

    it "A date should has a weekday property" do
      _(evaluate(' date("2020-09-30").weekday ')).must_equal 3
    end

    it "A date should return null if the property is not available" do
      _(evaluate(' date("2020-09-30").seconds ')).must_be_nil
    end

    it "A date should has properties with @-notation" do
      _(evaluate(' @"2017-03-10".year ')).must_equal 2017
      _(evaluate(' @"2017-03-10".month ')).must_equal 3
      _(evaluate(' @"2017-03-10".day ')).must_equal 10
    end

    # A time

    it "A time should has a hour property" do
      _(evaluate(' time("11:45:30+02:00").hour ')).must_equal 11
    end

    it "A time should has a minute property" do
      _(evaluate(' time("11:45:30+02:00").minute ')).must_equal 45
    end

    it "A time should has a second property" do
      _(evaluate(' time("11:45:30+02:00").second ')).must_equal 30
    end

    it "A time should has a time offset property" do
      _(evaluate(' time("11:45:30+02:00").time offset ')).must_equal 2.hours
    end

    it "A time should has a timezone property" do
      _(evaluate(' time("11:45:30@Europe/Paris").timezone ')).must_equal "Europe/Paris"

      _(evaluate(' time("11:45:30+02:00").timezone ')).must_be_nil
    end

    it "A time should return null if the property is not available" do
      _(evaluate(' time("11:45:30+02:00").day ')).must_be_nil
    end

    it "A time should has properties with @-notation" do
      _(evaluate(' @"11:45:30+02:00".hour ')).must_equal 11
      _(evaluate(' @"11:45:30+02:00".minute ')).must_equal 45
      _(evaluate(' @"11:45:30+02:00".second ')).must_equal 30
    end

    # A local time

    it "A local time should has a hour property" do
      _(evaluate(' time("11:45:30").hour ')).must_equal 11
    end

    it "A local time should has a minute property" do
      _(evaluate(' time("11:45:30").minute ')).must_equal 45
    end

    it "A local time should has a second property" do
      _(evaluate(' time("11:45:30").second ')).must_equal 30
    end

    it "A local time should has a time offset property = null" do
      _(evaluate(' time("11:45:30").time offset ')).must_be_nil
    end

    it "A local time should has a timezone property = null" do
      _(evaluate(' time("11:45:30").timezone ')).must_be_nil
    end

    it "A local time should return null if the property is not available" do
      _(evaluate(' time("11:45:30").day ')).must_be_nil
    end

    # A date-time

    it "A date-time should has a year property" do
      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").year ')).must_equal 2017
    end

    it "A date-time should has a month property" do
      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").month ')).must_equal 3
    end

    it "A date-time should has a day property" do
      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").day ')).must_equal 10
    end

    it "A date-time should has a weekday property" do
      _(evaluate(' date and time("2020-09-30T22:50:30+02:00").weekday ')).must_equal 3
    end

    it "A date-time should has a hour property" do
      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").hour ')).must_equal 11
    end

    it "A date-time should has a minute property" do
      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").minute ')).must_equal 45
    end

    it "A date-time should has a second property" do
      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").second ')).must_equal 30
    end

    it "A date-time should has a time offset property" do
      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").time offset ')).must_equal 2.hours
    end

    it "A date-time should has a variable with a time offset property" do
      # Ruby specific: Time, DateTime and TimeWithZone values (parenthesized, see the skip below)
      _(evaluate(" (dateTime).time offset ", dateTime: Time.new(2017, 3, 10, 11, 45, 30, "+02:00"))).must_equal 2.hours
      _(evaluate(" (dateTime).time offset ", dateTime: DateTime.new(2017, 3, 10, 11, 45, 30, "+02:00"))).must_equal 2.hours
      _(evaluate(" (dateTime).time offset ", dateTime: Time.find_zone!("Europe/Paris").local(2017, 3, 10, 11, 45, 30))).must_equal 1.hour

      _(evaluate(" dateTime.time offset ", dateTime: Time.new(2017, 3, 10, 11, 45, 30, "+02:00"))).must_equal 2.hours
    end

    it "A date-time should has a timezone property" do
      _(evaluate(' date and time("2017-03-10T11:45:30@Europe/Paris").timezone ')).must_equal "Europe/Paris"

      _(evaluate(' date and time("2017-03-10T11:45:30+02:00").timezone ')).must_be_nil
    end

    it "A date-time should return null if the property is not available" do
      _(evaluate(' date and time("2020-09-30T22:50:30+02:00").days ')).must_be_nil
    end

    it "A date-time should has properties with @-notation" do
      _(evaluate(' @"2017-03-10T11:45:30+02:00".year ')).must_equal 2017
      _(evaluate(' @"2017-03-10T11:45:30+02:00".month ')).must_equal 3
      _(evaluate(' @"2017-03-10T11:45:30+02:00".day ')).must_equal 10
    end

    # A local date-time

    it "A local date-time should has a year property" do
      _(evaluate(' date and time("2017-03-10T11:45:30").year ')).must_equal 2017
    end

    it "A local date-time should has a month property" do
      _(evaluate(' date and time("2017-03-10T11:45:30").month ')).must_equal 3
    end

    it "A local date-time should has a day property" do
      _(evaluate(' date and time("2017-03-10T11:45:30").day ')).must_equal 10
    end

    it "A local date-time should has a hour property" do
      _(evaluate(' date and time("2017-03-10T11:45:30").hour ')).must_equal 11
    end

    it "A local date-time should has a minute property" do
      _(evaluate(' date and time("2017-03-10T11:45:30").minute ')).must_equal 45
    end

    it "A local date-time should has a second property" do
      _(evaluate(' date and time("2017-03-10T11:45:30").second ')).must_equal 30
    end

    it "A local date-time should has a time offset property = null" do
      _(evaluate(' date and time("2017-03-10T11:45:30").time offset ')).must_be_nil
    end

    it "A local date-time should has a timezone property = null" do
      _(evaluate(' date and time("2017-03-10T11:45:30").timezone ')).must_be_nil
    end

    it "A local date-time should has a weekday property" do
      _(evaluate(' date and time("2020-09-30T22:50:30").weekday ')).must_equal 3
    end

    it "A local date-time should return null if the property is not available" do
      _(evaluate(' date and time("2020-09-30T22:50:30").days ')).must_be_nil
    end

    # A year-month-duration

    it "A year-month-duration should has a years property" do
      _(evaluate(' duration("P2Y3M").years ')).must_equal 2
    end

    it "A year-month-duration should has a months property" do
      _(evaluate(' duration("P2Y3M").months ')).must_equal 3
    end

    it "A year-month-duration should return null if the property is not available" do
      _(evaluate(' duration("P2Y3M").day ')).must_be_nil
    end

    it "A year-month-duration should has properties with @-notation" do
      _(evaluate(' @"P2Y3M".years ')).must_equal 2
      _(evaluate(' @"P2Y3M".months ')).must_equal 3
    end

    # A day-time-duration

    it "A day-time-duration should has a days property" do
      _(evaluate(' duration("P1DT2H10M30S").days ')).must_equal 1
    end

    it "A day-time-duration should has a hours property" do
      _(evaluate(' duration("P1DT2H10M30S").hours ')).must_equal 2
    end

    it "A day-time-duration should has a minutes property" do
      _(evaluate(' duration("P1DT2H10M30S").minutes ')).must_equal 10
    end

    it "A day-time-duration should has a seconds property" do
      _(evaluate(' duration("P1DT2H10M30S").seconds ')).must_equal 30
    end

    it "A day-time-duration should return null if the property is not available" do
      _(evaluate(' duration("P1DT2H10M30S").day ')).must_be_nil
    end

    it "A day-time-duration should has properties with @-notation" do
      _(evaluate(' @"P1DT2H10M30S".days ')).must_equal 1
      _(evaluate(' @"P1DT2H10M30S".hours ')).must_equal 2
      _(evaluate(' @"P1DT2H10M30S".minutes ')).must_equal 10
      _(evaluate(' @"P1DT2H10M30S".seconds ')).must_equal 30
    end
  end
end
