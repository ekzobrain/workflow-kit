# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinTemporalFunctionsTest
module FEEL
  describe "built-in temporal functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    let(:now) { Time.new(2020, 7, 31, 14, 27, 30, in: TZInfo::Timezone.get("Europe/Berlin")) }

    let(:date) { "date(2019,9,17)" }
    let(:local_date_time) { 'date and time("2019-09-17T14:30:00")' }
    let(:date_time) { 'date and time("2019-09-17T14:30:00@Europe/Berlin")' }

    it "The now() function should return the current date-time" do
      travel_to(now) do
        _(evaluate(" now() ")).must_equal now
      end
    end

    it "The today() function should return the current date" do
      travel_to(now) do
        _(evaluate(" today() ")).must_equal Date.new(2020, 7, 31)
      end
    end

    it "The day of year() function should return the day within the year" do
      _(evaluate("day of year(#{date})")).must_equal 260
      _(evaluate("day of year(#{local_date_time}) ")).must_equal 260
      _(evaluate("day of year(#{date_time}) ")).must_equal 260

      _(evaluate(' day of year(date("2019-12-31")) ')).must_equal 365
      _(evaluate(' day of year(date("2020-12-31")) ')).must_equal 366
    end

    it "The day of week() function should return the day of the week" do
      _(evaluate("day of week(#{date})")).must_equal "Tuesday"
      _(evaluate("day of week(#{local_date_time})")).must_equal "Tuesday"
      _(evaluate("day of week(#{date_time})")).must_equal "Tuesday"
    end

    it "The month of year() function should return the month of the year" do
      _(evaluate("month of year(#{date})")).must_equal "September"
      _(evaluate("month of year(#{local_date_time})")).must_equal "September"
      _(evaluate("month of year(#{date_time})")).must_equal "September"
    end

    it "The week of year() function should return the number of week within the year" do
      _(evaluate("week of year(#{date})")).must_equal 38
      _(evaluate("week of year(#{local_date_time})")).must_equal 38
      _(evaluate("week of year(#{date_time})")).must_equal 38

      _(evaluate(" week of year(date(2003,12,29)) ")).must_equal 1
      _(evaluate(" week of year(date(2004,1,4)) ")).must_equal 1
      _(evaluate(" week of year(date(2005,1,1)) ")).must_equal 53
      _(evaluate(" week of year(date(2005,1,3)) ")).must_equal 1
      _(evaluate(" week of year(date(2005,1,9)) ")).must_equal 1
    end

    it "A abs() function should return the absolute value of a days-time-duration" do
      _(evaluate(' abs(duration("PT5H")) ')).must_equal FEEL::Duration.hours(5)
      _(evaluate(' abs(duration("-PT5H")) ')).must_equal FEEL::Duration.hours(5)
      _(evaluate(' abs(duration("-PT5H")) instance of days and time duration ')).must_equal true
    end

    it "A abs() function should return the absolute value of a years-months-duration" do
      _(evaluate(' abs(duration("P2M")) ')).must_equal FEEL::Duration.months(2)
      _(evaluate(' abs(duration("-P2M")) ')).must_equal FEEL::Duration.months(2)
      _(evaluate(' abs(duration("-P2M")) instance of years and months duration ')).must_equal true
    end

    it "A last day of month() function should return the the last day of the month" do
      _(evaluate(" last day of month(date(2022,10,17)) ")).must_equal Date.new(2022, 10, 31)

      _(evaluate("last day of month(#{date})")).must_equal Date.new(2019, 9, 30)
      _(evaluate("last day of month(#{local_date_time})")).must_equal Date.new(2019, 9, 30)
      _(evaluate("last day of month(#{date_time})")).must_equal Date.new(2019, 9, 30)
    end

    it "A last day of month() function should take the leap years into account" do
      _(evaluate(' last day of month(date("2022-02-01")) ')).must_equal Date.new(2022, 2, 28)

      _(evaluate(' last day of month(date("2024-02-01")) ')).must_equal Date.new(2024, 2, 29)
    end
  end
end
