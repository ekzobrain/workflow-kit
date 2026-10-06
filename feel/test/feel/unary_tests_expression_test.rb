# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterUnaryTest
#
# Note: FEEL.test returns a boolean, a null result of the unary tests is
# reported as false (i.e. the input entry doesn't match).
module FEEL
  describe "unary tests expressions" do
    def test(input, text, variables = {})
      FEEL.test(input, text, variables: variables)
    end

    describe :number do
      it "should compare with operators" do
        _(test(2, "< 3")).must_equal true
        _(test(3, "< 3")).must_equal false
        _(test(3, "<= 3")).must_equal true
        _(test(4, "<= 3")).must_equal false
        _(test(4, "> 3")).must_equal true
        _(test(3, "> 3")).must_equal false
        _(test(3, ">= 3")).must_equal true
        _(test(2, ">= 3")).must_equal false
      end

      it "should be equal to another number" do
        _(test(2, "3")).must_equal false
        _(test(3, "3")).must_equal true
        _(test(-1, "-1")).must_equal true
        _(test(0, "-1")).must_equal false
      end

      it "should be in intervals" do
        _(test(2, "(2..4)")).must_equal false
        _(test(3, "(2..4)")).must_equal true
        _(test(4, "(2..4)")).must_equal false
        _(test(2, "[2..4]")).must_equal true
        _(test(4, "[2..4]")).must_equal true
        _(test(2, "]2..4]")).must_equal false
        _(test(4, "[2..4[")).must_equal false
        _(test(3, "[1..5], [6..10]")).must_equal true
        _(test(6, "[1..5], [6..10]")).must_equal true
        _(test(11, "[1..5], [6..10]")).must_equal false
      end

      it "should be negated" do
        _(test(2, "not(3)")).must_equal true
        _(test(3, "not(3)")).must_equal false
        _(test(2, "not(2,3)")).must_equal false
        _(test(4, "not(2,3)")).must_equal true
      end

      it "should compare to a variable" do
        _(test(2, "var", var: 3)).must_equal false
        _(test(3, "var", var: 3)).must_equal true
        _(test(2, "< var", var: 3)).must_equal true
        _(test(3, "< var", var: 3)).must_equal false
      end

      it "should compare to null" do
        _(test(nil, "3")).must_equal false
        _(test(nil, "< 3")).must_equal false
        _(test(nil, "(0..10)")).must_equal false
      end
    end

    describe :string do
      it "should be equal to another string" do
        _(test("a", '"b"')).must_equal false
        _(test("b", '"b"')).must_equal true
        _(test(nil, '"a"')).must_equal false
        _(test("a", '"a","b"')).must_equal true
        _(test("c", '"a","b"')).must_equal false
      end
    end

    describe :boolean do
      it "should be equal to another boolean" do
        _(test(false, "true")).must_equal false
        _(test(true, "false")).must_equal false
        _(test(false, "false")).must_equal true
        _(test(true, "true")).must_equal true
        _(test(nil, "true")).must_equal false
      end

      it "should compare to a boolean comparison" do
        _(test(true, "1 < 2")).must_equal true
        _(test(true, "2 < 1")).must_equal false
        _(test(true, '"a" = "a"')).must_equal true
        _(test(true, '"a" = "b"')).must_equal false
      end

      it "should compare to a conjunction" do
        _(test(true, "true and true")).must_equal true
        _(test(true, "false and true")).must_equal false
        _(test(true, "true and null")).must_equal false
        _(test(true, 'true and "otherwise"')).must_equal false
      end

      it "should compare to a disjunction" do
        _(test(true, "true or true")).must_equal true
        _(test(true, "false or true")).must_equal true
        _(test(true, "false or false")).must_equal false
        _(test(true, "true or null")).must_equal true
        _(test(true, "false or null")).must_equal false
      end
    end

    describe :temporal do
      it "should compare dates" do
        _(test(Date.parse("2015-09-17"), '< date("2015-09-18")')).must_equal true
        _(test(Date.parse("2015-09-18"), '< date("2015-09-18")')).must_equal false
        _(test(Date.parse("2015-09-18"), 'date("2015-09-18")')).must_equal true
        _(test(Date.parse("2015-09-18"), '(date("2015-09-17")..date("2015-09-19"))')).must_equal true
        _(test(Date.parse("2015-09-17"), '(date("2015-09-17")..date("2015-09-19"))')).must_equal false
        _(test(Date.parse("2015-09-17"), '[date("2015-09-17")..date("2015-09-19")]')).must_equal true
      end

      it "should compare date and times" do
        _(test(DateTime.parse("2015-09-17T08:31:14"), '< date and time("2015-09-17T10:00:00")')).must_equal true
        _(test(DateTime.parse("2015-09-17T10:10:00"), '< date and time("2015-09-17T10:00:00")')).must_equal false
        _(test(DateTime.parse("2015-09-17T08:31:14"), 'date and time("2015-09-17T08:31:14")')).must_equal true
        _(test(DateTime.parse("2015-09-17T09:15:20"), '[date and time("2015-09-17T08:00:00")..date and time("2015-09-17T10:00:00")]')).must_equal true
      end

      it "should compare durations" do
        _(test(1.year, '< duration("P2Y")')).must_equal true
        _(test(1.year, '< duration("P1Y")')).must_equal false
        _(test(ActiveSupport::Duration.parse("P1Y4M"), 'duration("P1Y4M")')).must_equal true
        _(test(ActiveSupport::Duration.parse("P1Y8M"), '[duration("P1Y")..duration("P2Y")]')).must_equal true
        _(test(ActiveSupport::Duration.parse("P1DT4H"), '< duration("P2DT4H")')).must_equal true
      end
    end

    describe :list do
      it "should be equal to another list" do
        _(test([], "[]")).must_equal true
        _(test([1, 2], "[1,2]")).must_equal true
        _(test([1, 2], "[]")).must_equal false
        _(test([1, 2], "[1]")).must_equal false
        _(test([1, 2], "[2,1]")).must_equal false
        _(test([1, 2], "[1,2,3]")).must_equal false
      end

      it "should be checked in quantified expressions" do
        _(test([1, 2, 3], "every x in ? satisfies x > 3")).must_equal false
        _(test([4, 5, 6], "every x in ? satisfies x > 3")).must_equal true
        _(test([1, 2, 3], "some x in ? satisfies x > 4")).must_equal false
        _(test([4, 5, 6], "some x in ? satisfies x > 4")).must_equal true
      end
    end

    describe :context do
      it "should be equal to another context" do
        _(test({}, "{}")).must_equal true
        _(test({ "x" => 1 }, "{x:1}")).must_equal true
        _(test({ x: 1 }, "{x:1}")).must_equal true
        _(test({ "x" => 1 }, "{}")).must_equal false
        _(test({ "x" => 1 }, "{x:2}")).must_equal false
        _(test({ "x" => 1 }, "{y:1}")).must_equal false
        _(test({ "x" => 1 }, "{x:1,y:2}")).must_equal false
      end
    end

    describe :null do
      it "should compare to null" do
        _(test(1, "null")).must_equal false
        _(test(true, "null")).must_equal false
        _(test("a", "null")).must_equal false
        _(test(nil, "null")).must_equal true
      end
    end

    describe :function do
      it "should be invoked with the input value" do
        _(test("foo", 'starts with(?, "f")')).must_equal true
        _(test("foo", 'starts with(?, "b")')).must_equal false
      end

      it "should be invoked as endpoint" do
        _(test(2, "< max([1,2,3])")).must_equal true
        _(test(2, "< min([1,2,3])")).must_equal false
      end

      it "should be invoked with the input value for a parameter with any type" do
        _(test(481, "list contains([481, 485, 551, 483], ?)")).must_equal true
        _(test(999, "list contains([481, 485, 551, 483], ?)")).must_equal false
      end
    end

    describe :expression do
      it "should return true if it evaluates to a value equal to the input" do
        _(test(5, "5")).must_equal true
        _(test(5, "2 + 3")).must_equal true
        _(test(5, "x", x: 5)).must_equal true
      end

      it "should return false if it evaluates to a value not equal to the input" do
        _(test(5, "3")).must_equal false
        _(test(5, "1 + 2")).must_equal false
        _(test(5, "x", x: 3)).must_equal false
      end

      it "should not match if it evaluates to a value of a different type" do
        _(test(5, '@"2024-08-19"')).must_equal false
      end

      it "should return true if it evaluates to a list that contains the input" do
        _(test(5, "[4,5,6]")).must_equal true
        _(test(5, "concatenate([1,2,3], [4,5,6])")).must_equal true
        _(test(5, "x", x: [4, 5, 6])).must_equal true
      end

      it "should return false if it evaluates to a list that doesn't contain the input" do
        _(test(5, "[1,2,3]")).must_equal false
        _(test(5, "concatenate([1,2], [3])")).must_equal false
        _(test(5, "x", x: [1, 2, 3])).must_equal false
      end

      it "should apply the input to a unary comparison" do
        _(test(5, "< 10")).must_equal true
        _(test(5, "[1..10]")).must_equal true
        _(test(5, "> x", x: 3)).must_equal true
        _(test(5, "< 3")).must_equal false
        _(test(5, "[1..3]")).must_equal false
        _(test(5, "> x", x: 10)).must_equal false
        _(test(5, '< @"2024-08-19"')).must_equal false
      end

      it "should assign the input to the special variable '?'" do
        _(test(5, "odd(?)")).must_equal true
        _(test(5, "abs(?) < 10")).must_equal true
        _(test(5, "? > x", x: 3)).must_equal true
        _(test(5, "even(?)")).must_equal false
        _(test(5, "abs(?) < 3")).must_equal false
        _(test(5, "? > x", x: 10)).must_equal false
      end

      it "should not match if the expression with '?' is not a boolean" do
        _(test(5, "abs(?)")).must_equal false
        _(test(5, "?")).must_equal false
        _(test(5, "? + not_existing")).must_equal false
      end

      it "should match null input if it evaluates to null" do
        _(test(nil, "null")).must_equal true
        _(test(nil, "2 + not_existing")).must_equal true
        _(test(nil, "not_existing")).must_equal true
        _(test(5, "2 + not_existing")).must_equal false
        _(test(5, "not_existing")).must_equal false
      end

      it "should assign null to the special variable '?'" do
        _(test(nil, "? = null")).must_equal true
        _(test(nil, "odd(?) or ? = null")).must_equal true
        _(test(nil, "? != null")).must_equal false
        _(test(nil, "odd(?) and ? != null")).must_equal false
        _(test(nil, "? < 10")).must_equal false
      end

      it "should return true if it evaluates to true" do
        _(test(3, "x", x: true)).must_equal true
        _(test(3, "4 < 10")).must_equal true
        _(test(3, "even(4)")).must_equal true
        _(test(3, "list contains([1,2,3], 3)")).must_equal true
      end

      it "should return false if it evaluates to false" do
        _(test(3, "x", x: false)).must_equal false
        _(test(3, "4 > 10")).must_equal false
        _(test(3, "odd(4)")).must_equal false
        _(test(3, "list contains([1,2], 3)")).must_equal false
      end

      it "should support between and in" do
        _(test(5, "? between 1 and 10")).must_equal true
        _(test(5, "? in [1..3]")).must_equal false
      end
    end

    describe :negation do
      it "should negate values" do
        _(test(3, "not(1)")).must_equal true
        _(test("b", 'not("a")')).must_equal true
        _(test(3, "not(3)")).must_equal false
        _(test("b", 'not("b")')).must_equal false
      end

      it "should not match values of a different type" do
        _(test("b", "not(1)")).must_equal false
        _(test(2, 'not("a")')).must_equal false
      end

      it "should negate unary comparisons" do
        _(test(5, "not(< 3)")).must_equal true
        _(test(5, "not([1..3])")).must_equal true
        _(test(5, "not(> x)", x: 10)).must_equal true
        _(test(5, "not(< 10)")).must_equal false
        _(test(5, "not([1..10])")).must_equal false
        _(test(5, "not(> x)", x: 3)).must_equal false
        _(test("a", "not(< 3)")).must_equal false
        _(test(nil, "not(< 3)")).must_equal false
      end

      it "should negate boolean expressions" do
        _(test(3, "not(x)", x: false)).must_equal true
        _(test(3, "not(4 > 10)")).must_equal true
        _(test(3, "not(odd(4))")).must_equal true
        _(test(3, "not(list contains([1,2], 3))")).must_equal true
        _(test(3, "not(x)", x: true)).must_equal false
        _(test(3, "not(4 < 10)")).must_equal false
        _(test(3, "not(even(4))")).must_equal false
      end

      it "should negate null" do
        _(test(5, "not(null)")).must_equal true
        _(test(5, "not(not_existing)")).must_equal true
        _(test(nil, "not(null)")).must_equal false
        _(test(nil, "not(not_existing)")).must_equal false
      end

      it "should negate disjunctions" do
        _(test(5, "not(2,3)")).must_equal true
        _(test(5, "not(< 3, > 10)")).must_equal true
        _(test(5, "not([0..3], [10..20])")).must_equal true
        _(test(3, "not(2,3)")).must_equal false
        _(test(1, "not(< 3, > 10)")).must_equal false
        _(test(1, "not([0..3], [10..20])")).must_equal false
        _(test("a", "not(2,3)")).must_equal false
      end
    end
  end
end
