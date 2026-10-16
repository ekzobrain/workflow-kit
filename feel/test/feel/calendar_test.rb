# frozen_string_literal: true

require "test_helper"

# Dates use the proleptic Gregorian calendar (like ISO 8601 and java.time)
# unless FEEL.config.calendar says otherwise.
module FEEL
  describe "Calendar" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    after { FEEL.config.calendar = :gregorian }

    it "should be the proleptic Gregorian calendar by default" do
      _(FEEL.config.calendar).must_equal :gregorian
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

    it "should be configurable" do
      FEEL.config.calendar = :italy
      _(evaluate('date("1500-02-29")')).must_equal Date.new(1500, 2, 29)
      _(evaluate('date("1582-10-10")')).must_be_nil
      _(evaluate('date("1582-10-15") - date("1582-10-04")')).must_equal Duration.days(1)

      FEEL.config.calendar = :julian
      _(evaluate('date("1900-02-29")')).must_equal Date.new(1900, 2, 29, Date::JULIAN)

      FEEL.config.calendar = Date::ENGLAND
      _(evaluate('date("1752-09-10")')).must_be_nil
    end

    it "should reject unknown calendars" do
      _ { FEEL.config.calendar = :maya }.must_raise ArgumentError
    end
  end
end
