# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterUnaryTest
#
# Note: FEEL.test returns a boolean, a null result of the unary tests is
# reported as false (i.e. the input entry doesn't match).
module FEEL
  describe "interpreter unary test" do
    def test(expression, input, variables = {})
      FEEL.test(input, expression, variables: variables)
    end

    # Temporal input values are created with the corresponding FEEL function,
    # the Ruby representation is owned by the temporal area.
    def date(text) = FEEL.evaluate(%(date("#{text}")))
    def local_time(text) = FEEL.evaluate(%(time("#{text}")))
    def offset_time(text) = FEEL.evaluate(%(time("#{text}")))
    def local_date_time(text) = FEEL.evaluate(%(date and time("#{text}")))
    def date_time(text) = FEEL.evaluate(%(date and time("#{text}")))
    def year_month_duration(text) = FEEL.evaluate(%(duration("#{text}")))
    def day_time_duration(text) = FEEL.evaluate(%(duration("#{text}")))

    describe "A number" do
      it "should compare with '<'" do
        _(test("< 3", 2)).must_equal true
        _(test("< 3", 3)).must_equal false
        _(test("< 3", 4)).must_equal false
      end

      it "should compare with '<='" do
        _(test("<= 3", 2)).must_equal true
        _(test("<= 3", 3)).must_equal true
        _(test("<= 3", 4)).must_equal false
      end

      it "should compare with '>'" do
        _(test("> 3", 2)).must_equal false
        _(test("> 3", 3)).must_equal false
        _(test("> 3", 4)).must_equal true
      end

      it "should compare with '>='" do
        _(test(">= 3", 2)).must_equal false
        _(test(">= 3", 3)).must_equal true
        _(test(">= 3", 4)).must_equal true
      end

      it "should be equal to another number" do
        _(test("3", 2)).must_equal false
        _(test("3", 3)).must_equal true

        _(test("-1", -1)).must_equal true
        _(test("-1", 0)).must_equal false
      end

      it "should be in interval '(2..4)'" do
        _(test("(2..4)", 2)).must_equal false
        _(test("(2..4)", 3)).must_equal true
        _(test("(2..4)", 4)).must_equal false
      end

      it "should be in interval '[2..4]'" do
        _(test("[2..4]", 2)).must_equal true
        _(test("[2..4]", 3)).must_equal true
        _(test("[2..4]", 4)).must_equal true
      end

      it "should be in one of two intervals (disjunction)" do
        _(test("[1..5], [6..10]", 3)).must_equal true
        _(test("[1..5], [6..10]", 6)).must_equal true
        _(test("[1..5], [6..10]", 11)).must_equal false
      end

      it "should be in '2,3'" do
        _(test("2,3", 2)).must_equal true
        _(test("2,3", 3)).must_equal true
        _(test("2,3", 4)).must_equal false
      end

      it "should be not equal 'not(3)'" do
        _(test("not(3)", 2)).must_equal true
        _(test("not(3)", 3)).must_equal false
        _(test("not(3)", 4)).must_equal true
      end

      it "should be not in 'not(2,3)'" do
        _(test("not(2,3)", 2)).must_equal false
        _(test("not(2,3)", 3)).must_equal false
        _(test("not(2,3)", 4)).must_equal true
      end

      it "should compare to a variable (qualified name)" do
        _(test("var", 2, var: 3)).must_equal false
        _(test("var", 3, var: 3)).must_equal true

        _(test("< var", 2, var: 3)).must_equal true
        _(test("< var", 3, var: 3)).must_equal false
      end

      # Not applicable: "compare to a field of a bean" uses a Java bean

      it "should compare to null" do
        _(test("3", nil)).must_equal false
      end

      it "should compare null with less/greater than" do
        _(test("< 3", nil)).must_equal false
        _(test("<= 3", nil)).must_equal false
        _(test("> 3", nil)).must_equal false
        _(test(">= 3", nil)).must_equal false
      end

      it "should compare null with interval" do
        _(test("(0..10)", nil)).must_equal false
      end
    end

    describe "A string" do
      it "should be equal to another string" do
        _(test(' "b" ', "a")).must_equal false
        _(test(' "b" ', "b")).must_equal true
      end

      it "should compare to null" do
        _(test(' "a" ', nil)).must_equal false
      end

      it "should be in '\"a\",\"b\"' " do
        _(test(' "a","b" ', "a")).must_equal true
        _(test(' "a","b" ', "b")).must_equal true
        _(test(' "a","b" ', "c")).must_equal false
      end
    end

    describe "A boolean" do
      it "should be equal to another boolean" do
        _(test("true", false)).must_equal false
        _(test("false", true)).must_equal false

        _(test("false", false)).must_equal true
        _(test("true", true)).must_equal true
      end

      it "should compare to null" do
        _(test("true", nil)).must_equal false
        _(test("false", nil)).must_equal false
      end

      it "should compare to a boolean comparison (numeric)" do
        _(test("1 < 2", true)).must_equal true
        _(test("2 < 1", true)).must_equal false
      end

      it "should compare to a boolean comparison (string)" do
        _(test(' "a" = "a" ', true)).must_equal true
        _(test(' "a" = "b" ', true)).must_equal false
      end

      it "should compare to a conjunction (and)" do
        # it is uncommon to use a conjunction in a unary-tests but the engine should be able to parse
        _(test("true and true", true)).must_equal true
        _(test("false and true", true)).must_equal false

        _(test("true and null", true)).must_equal false
        _(test("false and null", true)).must_equal false

        _(test('true and "otherwise" ', true)).must_equal false
        _(test('false and "otherwise" ', true)).must_equal false
      end

      it "should compare to a disjunction (or)" do
        # it is uncommon to use a disjunction in a unary-tests but the engine should be able to parse
        _(test("true or true", true)).must_equal true
        _(test("false or true", true)).must_equal true
        _(test("false or false", true)).must_equal false

        _(test("true or null", true)).must_equal true
        _(test("false or null", true)).must_equal false

        _(test('true or "otherwise" ', true)).must_equal true
        _(test('false or "otherwise" ', true)).must_equal false
      end
    end

    describe "A date" do
      it "should compare with '<'" do
        _(test('< date("2015-09-18")', date("2015-09-17"))).must_equal true
        _(test('< date("2015-09-18")', date("2015-09-18"))).must_equal false
        _(test('< date("2015-09-18")', date("2015-09-19"))).must_equal false
      end

      it "should compare with '<='" do
        _(test('<= date("2015-09-18")', date("2015-09-17"))).must_equal true
        _(test('<= date("2015-09-18")', date("2015-09-18"))).must_equal true
        _(test('<= date("2015-09-18")', date("2015-09-19"))).must_equal false
      end

      it "should compare with '>'" do
        _(test('> date("2015-09-18")', date("2015-09-17"))).must_equal false
        _(test('> date("2015-09-18")', date("2015-09-18"))).must_equal false
        _(test('> date("2015-09-18")', date("2015-09-19"))).must_equal true
      end

      it "should compare with '>='" do
        _(test('>= date("2015-09-18")', date("2015-09-17"))).must_equal false
        _(test('>= date("2015-09-18")', date("2015-09-18"))).must_equal true
        _(test('>= date("2015-09-18")', date("2015-09-19"))).must_equal true
      end

      it "should be equal to another date" do
        _(test('date("2015-09-18")', date("2015-09-17"))).must_equal false
        _(test('date("2015-09-18")', date("2015-09-18"))).must_equal true
      end

      it "should be in interval '(date(\"2015-09-17\")..date(\"2015-09-19\")]'" do
        _(test('(date("2015-09-17")..date("2015-09-19"))', date("2015-09-17"))).must_equal false
        _(test('(date("2015-09-17")..date("2015-09-19"))', date("2015-09-18"))).must_equal true
        _(test('(date("2015-09-17")..date("2015-09-19"))', date("2015-09-19"))).must_equal false
      end

      it "should be in interval '[date(\"2015-09-17\")..date(\"2015-09-19\")]'" do
        _(test('[date("2015-09-17")..date("2015-09-19")]', date("2015-09-17"))).must_equal true
        _(test('[date("2015-09-17")..date("2015-09-19")]', date("2015-09-18"))).must_equal true
        _(test('[date("2015-09-17")..date("2015-09-19")]', date("2015-09-19"))).must_equal true
      end
    end

    describe "A time" do
      it "should compare with '<'" do
        _(test('< time("10:00:00")', local_time("08:31:14"))).must_equal true
        _(test('< time("10:00:00")', local_time("10:10:00"))).must_equal false
        _(test('< time("10:00:00")', local_time("11:31:14"))).must_equal false

        _(test('< time("11:00:00+01:00")', offset_time("10:00:00+01:00"))).must_equal true
        _(test('< time("10:00:00+01:00")', offset_time("10:00:00+01:00"))).must_equal false
      end

      it "should be equal to another time" do
        _(test('time("10:00:00")', local_time("08:31:14"))).must_equal false
        _(test('time("08:31:14")', local_time("08:31:14"))).must_equal true

        _(test('time("10:00:00+02:00")', offset_time("10:00:00+01:00"))).must_equal false
        _(test('time("11:00:00+02:00")', offset_time("10:00:00+01:00"))).must_equal false
        _(test('time("10:00:00+01:00")', offset_time("10:00:00+01:00"))).must_equal true
      end

      it "should be in interval '[time(\"08:00:00\")..time(\"10:00:00\")]'" do
        _(test('[time("08:00:00")..time("10:00:00")]', local_time("07:45:10"))).must_equal false
        _(test('[time("08:00:00")..time("10:00:00")]', local_time("09:15:20"))).must_equal true
        _(test('[time("08:00:00")..time("10:00:00")]', local_time("11:30:30"))).must_equal false

        _(test('[time("08:00:00+01:00")..time("10:00:00+01:00")]', offset_time("11:30:00+01:00"))).must_equal false
        _(test('[time("08:00:00+01:00")..time("10:00:00+01:00")]', offset_time("09:30:00+01:00"))).must_equal true
      end
    end

    describe "A date-time" do
      it "should compare with '<'" do
        _(test('< date and time("2015-09-17T10:00:00")', local_date_time("2015-09-17T08:31:14"))).must_equal true
        _(test('< date and time("2015-09-17T10:00:00")', local_date_time("2015-09-17T10:10:00"))).must_equal false
        _(test('< date and time("2015-09-17T10:00:00")', local_date_time("2015-09-17T11:31:14"))).must_equal false

        _(test('< date and time("2015-09-17T12:00:00+01:00")', date_time("2015-09-17T10:00:00+01:00"))).must_equal true
        _(test('< date and time("2015-09-17T09:00:00+01:00")', date_time("2015-09-17T10:00:00+01:00"))).must_equal false
      end

      it "should be equal to another date-time" do
        _(test('date and time("2015-09-17T10:00:00")', local_date_time("2015-09-17T08:31:14"))).must_equal false
        _(test('date and time("2015-09-17T08:31:14")', local_date_time("2015-09-17T08:31:14"))).must_equal true

        _(test('date and time("2015-09-17T09:30:00+01:00")', date_time("2015-09-17T08:30:00+01:00"))).must_equal false
        _(test('date and time("2015-09-17T08:30:00+02:00")', date_time("2015-09-17T08:30:00+01:00"))).must_equal false
        _(test('date and time("2015-09-17T08:30:00+01:00")', date_time("2015-09-17T08:30:00+01:00"))).must_equal true
      end

      it "should be in interval '[dante and time(\"2015-09-17T08:00:00\")..date and time(\"2015-09-17T10:00:00\")]'" do
        _(test('[date and time("2015-09-17T08:00:00")..date and time("2015-09-17T10:00:00")]', local_date_time("2015-09-17T07:45:10"))).must_equal false
        _(test('[date and time("2015-09-17T08:00:00")..date and time("2015-09-17T10:00:00")]', local_date_time("2015-09-17T09:15:20"))).must_equal true
        _(test('[date and time("2015-09-17T08:00:00")..date and time("2015-09-17T10:00:00")]', local_date_time("2015-09-17T11:30:30"))).must_equal false

        _(test('[date and time("2015-09-17T09:00:00+01:00")..date and time("2015-09-17T10:00:00+01:00")]', date_time("2015-09-17T08:30:00+01:00"))).must_equal false
        _(test('[date and time("2015-09-17T08:00:00+01:00")..date and time("2015-09-17T10:00:00+01:00")]', date_time("2015-09-17T08:30:00+01:00"))).must_equal true
      end
    end

    describe "A year-month-duration" do
      it "should compare with '<'" do
        _(test('< duration("P2Y")', year_month_duration("P1Y"))).must_equal true
        _(test('< duration("P1Y")', year_month_duration("P1Y"))).must_equal false
        _(test('< duration("P1Y")', year_month_duration("P1Y2M"))).must_equal false
      end

      it "should be equal to another duration" do
        _(test('duration("P1Y3M")', year_month_duration("P1Y4M"))).must_equal false
        _(test('duration("P1Y4M")', year_month_duration("P1Y4M"))).must_equal true
      end

      it "should be in interval '[duration(\"P1Y\")..duration(\"P2Y\")]'" do
        _(test('[duration("P1Y")..duration("P2Y")]', year_month_duration("P6M"))).must_equal false
        _(test('[duration("P1Y")..duration("P2Y")]', year_month_duration("P1Y8M"))).must_equal true
        _(test('[duration("P1Y")..duration("P2Y")]', year_month_duration("P2Y1M"))).must_equal false
      end
    end

    describe "A day-time-duration" do
      it "should compare with '<'" do
        _(test('< duration("P2DT4H")', day_time_duration("P1DT4H"))).must_equal true
        _(test('< duration("P2DT4H")', day_time_duration("P2DT4H"))).must_equal false
        _(test('< duration("P2DT4H")', day_time_duration("P2DT8H"))).must_equal false
      end

      it "should be equal to another duration" do
        _(test('duration("P2DT4H")', day_time_duration("P1DT4H"))).must_equal false
        _(test('duration("P2DT4H")', day_time_duration("P2DT4H"))).must_equal true
      end

      it "should be in interval '[duration(\"P1D\")..duration(\"P2D\")]'" do
        _(test('[duration("P1D")..duration("P2D")]', day_time_duration("PT4H"))).must_equal false
        _(test('[duration("P1D")..duration("P2D")]', day_time_duration("P1DT4H"))).must_equal true
        _(test('[duration("P1D")..duration("P2D")]', day_time_duration("P2DT4H"))).must_equal false
      end
    end

    describe "A list" do
      it "should be equal to another list" do
        _(test("[]", [])).must_equal true
        _(test("[1,2]", [1, 2])).must_equal true

        _(test("[]", [1, 2])).must_equal false
        _(test("[1]", [1, 2])).must_equal false
        _(test("[2,1]", [1, 2])).must_equal false
        _(test("[1,2,3]", [1, 2])).must_equal false
      end

      it "should be checked in an every expression" do
        _(test("every x in ? satisfies x > 3", [1, 2, 3])).must_equal false
        _(test("every x in ? satisfies x > 3", [4, 5, 6])).must_equal true
      end

      it "should be checked in a some expression" do
        _(test("some x in ? satisfies x > 4", [1, 2, 3])).must_equal false
        _(test("some x in ? satisfies x > 4", [4, 5, 6])).must_equal true
      end
    end

    describe "A context" do
      it "should be equal to another context" do
        _(test("{}", {})).must_equal true
        _(test("{x:1}", { "x" => 1 })).must_equal true

        _(test("{}", { "x" => 1 })).must_equal false
        _(test("{x:2}", { "x" => 1 })).must_equal false
        _(test("{y:1}", { "x" => 1 })).must_equal false
        _(test("{x:1,y:2}", { "x" => 1 })).must_equal false
      end
    end

    describe "An empty expression ('-')" do
      it "should be always true" do
        _(test("-", nil)).must_equal true
      end
    end

    describe "A null expression" do
      it "should compare to null" do
        _(test("null", 1)).must_equal false
        _(test("null", true)).must_equal false
        _(test("null", "a")).must_equal false

        _(test("null", nil)).must_equal true
      end
    end

    describe "A function" do
      it "should be invoked with the special variable '?'" do
        _(test(' starts with(?, "f") ', "foo")).must_equal true
        _(test(' starts with(?, "b") ', "foo")).must_equal false
      end

      it "should be invoked as endpoint" do
        _(test("< max(1,2,3)", 2)).must_equal true
        _(test("< min(1,2,3)", 2)).must_equal false
      end

      it "should be invoked with the special variable '?' for a parameter with ANY type" do
        _(test("list contains([481, 485, 551, 483], ?)", 481)).must_equal true
        _(test("list contains([481, 485, 551, 483], ?)", 999)).must_equal false
      end
    end

    describe "A unary-tests expression" do
      it "should return true if it evaluates to a value that is equal to the implicit value" do
        _(test("5", 5)).must_equal true
        _(test("2 + 3", 5)).must_equal true
        _(test("x", 5, x: 5)).must_equal true
      end

      it "should return false if it evaluates to a value that is not equal to the implicit value" do
        _(test("3", 5)).must_equal false
        _(test("1 + 2", 5)).must_equal false
        _(test("x", 5, x: 3)).must_equal false
      end

      it "should return null if it evaluates to a value that has a different type than the implicit value" do
        _(test(' @"2024-08-19" ', 5)).must_equal false
      end

      it "should return true if it evaluates to a list that contains the implicit value" do
        _(test("[4,5,6]", 5)).must_equal true
        _(test("concatenate([1,2,3], [4,5,6])", 5)).must_equal true
        _(test("x", 5, x: [4, 5, 6])).must_equal true
      end

      it "should return false if it evaluates to a list that doesn't contain the implicit value" do
        _(test("[1,2,3]", 5)).must_equal false
        _(test("concatenate([1,2], [3])", 5)).must_equal false
        _(test("x", 5, x: [1, 2, 3])).must_equal false
      end

      it "should return true if it evaluates to true when the implicit value is applied to it" do
        _(test("< 10", 5)).must_equal true
        _(test("[1..10]", 5)).must_equal true
        _(test("> x", 5, x: 3)).must_equal true
      end

      it "should return false if it evaluates to false when the implicit value is applied to it" do
        _(test("< 3", 5)).must_equal false
        _(test("[1..3]", 5)).must_equal false
        _(test("> x", 5, x: 10)).must_equal false
      end

      it "should return null if it evaluates to null when the implicit value is applied to it" do
        _(test(' < @"2024-08-19" ', 5)).must_equal false
        _(test(' < @"2024-08-19" ', nil)).must_equal false
      end

      it "should return true if it evaluates to true when the implicit value is assigned to the special variable '?'" do
        _(test("odd(?)", 5)).must_equal true
        _(test("abs(?) < 10", 5)).must_equal true
        _(test("? > x", 5, x: 3)).must_equal true
      end

      it "should return false if it evaluates to false when the implicit value is assigned to the special variable '?'" do
        _(test("even(?)", 5)).must_equal false
        _(test("abs(?) < 3", 5)).must_equal false
        _(test("? > x", 5, x: 10)).must_equal false
      end

      it "should return null if it evaluates to a value that is not a boolean when the implicit value is assigned to the special variable '?'" do
        _(test("abs(?)", 5)).must_equal false
        _(test("?", 5)).must_equal false
        _(test("? + not_existing", 5)).must_equal false
      end

      it "should return true if it evaluates to null and the implicit value is null" do
        _(test("null", nil)).must_equal true
        _(test("2 + not_existing", nil)).must_equal true
        _(test("not_existing", nil)).must_equal true
      end

      it "should return false if it evaluates to null and the implicit value is not null" do
        _(test("null", 5)).must_equal false
        _(test("2 + not_existing", 5)).must_equal false
        _(test("not_existing", 5)).must_equal false
      end

      it "should return true if it evaluates to true when null is assigned to the special variable '?'" do
        _(test("? = null", nil)).must_equal true
        _(test("odd(?) or ? = null", nil)).must_equal true
      end

      it "should return false if it evaluates to false when null is assigned to the special variable '?'" do
        _(test("? != null", nil)).must_equal false
        _(test("odd(?) and ? != null", nil)).must_equal false
      end

      it "should return null if it evaluates to null when null is assigned to the special variable '?'" do
        _(test("? < 10", nil)).must_equal false
        _(test("odd(?)", nil)).must_equal false
        _(test("5 < ? and ? < 10", nil)).must_equal false
        _(test("5 < ? or ? < 10", nil)).must_equal false
      end

      it "should return true if it evaluates to true" do
        _(test("x", 3, x: true)).must_equal true
        _(test("4 < 10", 3)).must_equal true
        _(test("even(4)", 3)).must_equal true
        _(test("list contains([1,2,3], 3)", 3)).must_equal true
      end

      it "should return false if it evaluates to false" do
        _(test("x", 3, x: false)).must_equal false
        _(test("4 > 10", 3)).must_equal false
        _(test("odd(4)", 3)).must_equal false
        _(test("list contains([1,2], 3)", 3)).must_equal false
      end
    end

    describe "A negation" do
      it "should return true if it evaluates to a value that is not equal to the implicit value" do
        _(test("not(1)", 3)).must_equal true
        _(test(' not("a") ', "b")).must_equal true
      end

      it "should return false if it evaluates to a value that is equal to the implicit value" do
        _(test("not(3)", 3)).must_equal false
        _(test(' not("b") ', "b")).must_equal false
      end

      it "should return null if it evaluates to a value that has a different type than the implicit value" do
        _(test("not(1)", "b")).must_equal false
        _(test(' not("a") ', 2)).must_equal false
      end

      it "should return true if it evaluates to false when the implicit value is applied to it" do
        _(test("not(< 3)", 5)).must_equal true
        _(test("not([1..3])", 5)).must_equal true
        _(test("not(> x)", 5, x: 10)).must_equal true
      end

      it "should return false if it evaluates to true when the implicit value is applied to it" do
        _(test("not(< 10)", 5)).must_equal false
        _(test("not([1..10])", 5)).must_equal false
        _(test("not(> x)", 5, x: 3)).must_equal false
      end

      it "should return null if it evaluates to null when the implicit value is applied to it" do
        _(test("not(< 3)", "a")).must_equal false
        _(test("not(< 3)", nil)).must_equal false
      end

      it "should return true if it evaluates to false" do
        _(test("not(x)", 3, x: false)).must_equal true
        _(test("not(4 > 10)", 3)).must_equal true
        _(test("not(odd(4))", 3)).must_equal true
        _(test("not(list contains([1,2], 3))", 3)).must_equal true
      end

      it "should return false if it evaluates to true" do
        _(test("not(x)", 3, x: true)).must_equal false
        _(test("not(4 < 10)", 3)).must_equal false
        _(test("not(even(4))", 3)).must_equal false
        _(test("not(list contains([1,2,3], 3))", 3)).must_equal false
      end

      it "should return true if it evaluates to null and the implicit value is not null" do
        _(test("not(null)", 5)).must_equal true
        _(test("not(not_existing)", 5)).must_equal true
      end

      it "should return false if it evaluates to null and the implicit value is null" do
        _(test("not(null)", nil)).must_equal false
        _(test("not(not_existing)", nil)).must_equal false
      end

      it "should return true if a disjunction evaluates to false" do
        _(test("not(2,3)", 5)).must_equal true
        _(test("not(< 3, > 10)", 5)).must_equal true
        _(test("not([0..3], [10..20])", 5)).must_equal true
      end

      it "should return false if a disjunction evaluates to true" do
        _(test("not(2,3)", 3)).must_equal false
        _(test("not(< 3, > 10)", 1)).must_equal false
        _(test("not([0..3], [10..20])", 1)).must_equal false
      end

      it "should return null if a disjunction evaluates to null" do
        _(test("not(2,3)", "a")).must_equal false
        _(test("not(< 3, > 10)", "a")).must_equal false
        _(test("not([0..3], [10..20])", "a")).must_equal false
      end
    end
  end
end
