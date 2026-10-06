# frozen_string_literal: true

require "test_helper"

# Comparison tests that are not covered by the ported feel-scala tests of
# test/feel/interpreter/ (between and in from InterpreterNumberExpressionTest,
# additional instance of checks).
module FEEL
  describe "comparison expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe :between do
      it "should check if a value is between two values (inclusive)" do
        _(evaluate("x between 2 and 4", x: 1)).must_equal false
        _(evaluate("x between 2 and 4", x: 2)).must_equal true
        _(evaluate("x between 2 and 4", x: 3)).must_equal true
        _(evaluate("x between 2 and 4", x: 4)).must_equal true
        _(evaluate("x between 2 and 4", x: 5)).must_equal false
      end

      it "should support expressions as bounds" do
        _(evaluate("x between low + 1 and high * 2", x: 5, low: 1, high: 3)).must_equal true
        _(evaluate('"b" between "a" and "c"')).must_equal true
        _(evaluate('date("2020-06-01") between date("2020-01-01") and date("2020-12-31")')).must_equal true
      end

      it "should return null for null values" do
        _(evaluate("x between 2 and 4")).must_be_nil
        _(evaluate("3 between null and 4")).must_be_nil
      end
    end

    describe :in do
      it "should support the examples from the specification" do
        _(evaluate("1 in [1..10]")).must_equal true
        _(evaluate("1 in (1..10]")).must_equal false
        _(evaluate("10 in [1..10]")).must_equal true
        _(evaluate("10 in [1..10)")).must_equal false
      end

      it "should check against a value" do
        _(evaluate("x in 3", x: 3)).must_equal true
        _(evaluate("x in 3", x: 2)).must_equal false
        _(evaluate('x in "a"', x: "a")).must_equal true
      end

      it "should check against a unary comparison" do
        _(evaluate("x in < 3", x: 2)).must_equal true
        _(evaluate("x in < 3", x: 3)).must_equal false
        _(evaluate("x in >= 3", x: 3)).must_equal true
      end

      it "should check against a list of tests" do
        _(evaluate("x in (2, 3)", x: 3)).must_equal true
        _(evaluate("x in (2, 3)", x: 4)).must_equal false
        _(evaluate("x in (< 2, > 5)", x: 6)).must_equal true
        _(evaluate("x in ([1..2], [5..6])", x: 5)).must_equal true
        _(evaluate("x in ([1..2], [5..6])", x: 4)).must_equal false
      end

      it "should check against a list" do
        _(evaluate("x in [1, 2, 3]", x: 2)).must_equal true
        _(evaluate("x in [1, 2, 3]", x: 5)).must_equal false
        _(evaluate("x in xs", x: 2, xs: [1, 2, 3])).must_equal true
      end

      it "should combine with conjunctions" do
        _(evaluate("x in [1..5] and y in [1..5]", x: 2, y: 3)).must_equal true
        _(evaluate("x in [1..5] and y in [1..5]", x: 2, y: 7)).must_equal false
      end

      it "should return null for null values" do
        _(evaluate("x in < 3")).must_be_nil
      end
    end

    describe :instance_of do
      it "should check durations" do
        _(evaluate('duration("PT4H") instance of years and months duration')).must_equal false
        _(evaluate('duration("P3M") instance of duration')).must_equal true
      end

      it "should check date and times" do
        _(evaluate('date and time("2023-03-07T11:27:00") instance of date')).must_equal false
      end

      it "should check lists" do
        _(evaluate("[1,2,3] instance of list<number>")).must_equal true
      end
    end

    describe :incompatible_types do
      it "should return null when comparing values of different types" do
        _(evaluate('1 < "a"')).must_be_nil
        _(evaluate("true < false")).must_be_nil
      end
    end
  end
end
