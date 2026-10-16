# frozen_string_literal: true

require "test_helper"

# Dates use the proleptic Gregorian calendar (like ISO 8601, java.time and
# Ruby's Time), not the default of Ruby's Date (Julian before 1582-10-15).
module FEEL
  describe "Calendar" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    it "should be the proleptic Gregorian calendar" do
      _(evaluate('date("1582-10-10")')).must_equal Date.new(1582, 10, 10, Date::GREGORIAN)
      _(evaluate('date("1500-02-29")')).must_be_nil
      _(evaluate("date(1500, 2, 29)")).must_be_nil
      _(evaluate('date and time("1500-02-29T00:00:00")')).must_be_nil
      _(evaluate('date("1582-10-04") + duration("P1D")')).must_equal Date.new(1582, 10, 5, Date::GREGORIAN)
      _(evaluate('date("1582-10-15") - date("1582-10-04")')).must_equal Duration.days(11)
      _(evaluate('day of week(date("1000-01-01"))')).must_equal "Wednesday"
      _(evaluate('last day of month(date("1500-02-01"))')).must_equal Date.new(1500, 2, 28, Date::GREGORIAN)
    end

    it "should agree with date-times" do
      _(evaluate('date(date and time("1000-01-01T10:00:00")) = date("1000-01-01")')).must_equal true
      _(evaluate('date and time(date("1000-01-01"), time("10:00:00"))')).must_equal LocalDateTime.new(1000, 1, 1, 10, 0, 0)
    end

    it "should read Ruby dates with their year, month and day" do
      ruby_date = Date.new(1500, 2, 28) # Julian (Date::ITALY)
      _(evaluate('x = @"1500-02-28"', x: ruby_date)).must_equal true
      _(evaluate('x + duration("P1D")', x: ruby_date)).must_equal Date.new(1500, 3, 1, Date::GREGORIAN)
      _(evaluate("x", x: Date.new(2020, 1, 1))).must_equal Date.new(2020, 1, 1)
    end

    it "should return Gregorian dates" do
      _(evaluate('date("1500-03-01")').start).must_equal Date::GREGORIAN
      _(evaluate("x", x: Date.new(1500, 3, 1)).start).must_equal Date::GREGORIAN
    end
  end
end
