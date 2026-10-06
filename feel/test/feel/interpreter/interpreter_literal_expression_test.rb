# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterLiteralExpressionTest
module FEEL
  describe "interpreter literal expression" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A literal" do
      it "should be a number" do
        _(evaluate("2")).must_equal 2
        _(evaluate("2.4")).must_equal 2.4
        _(evaluate("-3")).must_equal(-3)
        _(evaluate("02")).must_equal 2
        _(evaluate("02.4")).must_equal 2.4
        _(evaluate("-03")).must_equal(-3)
        _(evaluate("0000002")).must_equal 2
      end

      it "should be a string" do
        _(evaluate(' "a" ')).must_equal "a"
      end

      it "should be a boolean" do
        _(evaluate("true")).must_equal true
      end

      it "should be null" do
        _(evaluate("null")).must_be_nil
      end

      it "should be a context (identifier as key)" do
        _(evaluate("{ a : 1 }")).must_equal({ "a" => 1 })

        _(evaluate('{ a:1, b:"foo" }')).must_equal({ "a" => 1, "b" => "foo" })

        # nested
        _(evaluate("{ a : { b : 1 } }")).must_equal({ "a" => { "b" => 1 } })
      end

      it "should be a context (string as key)" do
        _(evaluate(' {"a":1} ')).must_equal({ "a" => 1 })
      end

      it "should be a list" do
        _(evaluate("[1]")).must_equal [1]

        _(evaluate("[1,2]")).must_equal [1, 2]

        # nested
        _(evaluate("[ [1], [2] ]")).must_equal [[1], [2]]
      end
    end

    describe "A date literal" do
      it "should be defined" do
        _(evaluate(' date("2021-09-08") ')).must_equal Date.new(2021, 9, 8)
      end

      it "should be defined with '@'" do
        _(evaluate(' @"2021-09-08" ')).must_equal Date.new(2021, 9, 8)
      end

      it "should be null if the date is not valid (leap year)" do
        _(evaluate(' date("2023-02-29") ')).must_be_nil
        _(evaluate(' @"2023-02-29" ')).must_be_nil
      end

      it "should be null if the date is not valid (month with 31 days)" do
        _(evaluate(' date("2023-06-31") ')).must_be_nil
        _(evaluate(' @"2023-06-31" ')).must_be_nil
      end
    end

    describe "A time literal" do
      it "should be defined without offset" do
        # the Ruby representation of a local time is owned by the temporal area,
        # compare its components
        result = evaluate(' time("10:30:00") ')
        _([result.hour, result.min, result.sec]).must_equal [10, 30, 0]
      end

      it "should be defined with offset" do
        result = evaluate(' time("10:30:00+02:00") ')
        _([result.hour, result.min, result.utc_offset]).must_equal [10, 30, 2 * 3600]
      end

      it "should be defined with timezone" do
        result = evaluate(' time("10:30:00@Europe/Berlin") ')
        _([result.hour, result.min, result.utc_offset]).must_equal [10, 30, 3600]
      end

      it "should be defined with '@' and no offset" do
        result = evaluate(' @"10:30:00" ')
        _([result.hour, result.min, result.sec]).must_equal [10, 30, 0]
      end

      it "should be defined with '@' and offset" do
        result = evaluate(' @"10:30:00+02:00" ')
        _([result.hour, result.min, result.utc_offset]).must_equal [10, 30, 2 * 3600]
      end

      it "should be defined with '@' and timezone" do
        result = evaluate(' @"10:30:00@Europe/Berlin" ')
        _([result.hour, result.min, result.utc_offset]).must_equal [10, 30, 3600]
      end
    end

    describe "A date-time literal" do
      it "should be defined without offset" do
        _(evaluate(' date and time("2021-09-08T10:30:00") ')).must_equal FEEL::LocalDateTime.new(2021, 9, 8, 10, 30, 0)
      end

      it "should be defined with offset" do
        _(evaluate(' date and time("2021-09-08T10:30:00+02:00") ')).must_equal Time.new(2021, 9, 8, 10, 30, 0, "+02:00")
      end

      it "should be defined with timezone" do
        result = evaluate(' date and time("2021-09-08T10:30:00@Europe/Berlin") ')
        _(result).must_equal Time.new(2021, 9, 8, 10, 30, 0, "+02:00")
      end

      it "should be defined in ISO format with timezone" do
        result = evaluate(' date and time("2021-09-08T10:30:00+02:00[Europe/Berlin]") ')
        _(evaluate("x.timezone", x: result)).must_equal "Europe/Berlin"
      end

      it "should be defined with '@' and no offset" do
        _(evaluate(' @"2021-09-08T10:30:00" ')).must_equal FEEL::LocalDateTime.new(2021, 9, 8, 10, 30, 0)
      end

      it "should be defined with '@' and offset" do
        _(evaluate(' @"2021-09-08T10:30:00+02:00" ')).must_equal Time.new(2021, 9, 8, 10, 30, 0, "+02:00")
      end

      it "should be defined with '@' and timezone" do
        result = evaluate(' @"2021-09-08T10:30:00@Europe/Berlin" ')
        _(result).must_equal Time.new(2021, 9, 8, 10, 30, 0, "+02:00")
      end

      it "should be defined with '@' in ISO format with timezone" do
        result = evaluate(' @"2021-09-08T10:30:00+02:00[Europe/Berlin]" ')
        _(evaluate("x.timezone", x: result)).must_equal "Europe/Berlin"
      end

      it "should be null if the date is not valid (leap year)" do
        _(evaluate(' date and time("2023-02-29T10:00:00") ')).must_be_nil
        _(evaluate(' @"2023-02-29T10:00:00" ')).must_be_nil

        _(evaluate(' date and time("2023-02-29T10:00:00+02:00") ')).must_be_nil
        _(evaluate(' @"2023-02-29T10:00:00+02:00" ')).must_be_nil
      end

      it "should be null if the date is not valid (month with 31 days)" do
        _(evaluate(' date and time("2023-06-31T10:00:00") ')).must_be_nil
        _(evaluate(' @"2023-06-31T10:00:00" ')).must_be_nil

        _(evaluate(' date and time("2023-06-31T10:00:00+02:00") ')).must_be_nil
        _(evaluate(' @"2023-06-31T10:00:00+02:00" ')).must_be_nil
      end
    end

    describe "A years-months duration" do
      it "should be defined" do
        _(evaluate(' duration("P1Y6M") ')).must_equal FEEL::Duration.parse("P1Y6M")
      end

      it "should be defined with '@'" do
        _(evaluate(' @"P1Y6M" ')).must_equal FEEL::Duration.parse("P1Y6M")
      end
    end

    describe "A days-time duration" do
      it "should be defined" do
        _(evaluate(' duration("P1DT12H30M") ')).must_equal FEEL::Duration.parse("P1DT12H30M")
      end

      it "should be defined with '@'" do
        _(evaluate(' @"P1DT12H30M" ')).must_equal FEEL::Duration.parse("P1DT12H30M")
      end
    end
  end
end
