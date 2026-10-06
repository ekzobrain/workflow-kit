# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: ComparisonTypeTest
#
# Note: suppressed failures (reportFailure) are not supported, only the result
# is checked. A null result of unary tests is reported as false by FEEL.test.
module FEEL
  describe "comparison type" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "An equal operator" do
      it "should compare two values of the same type" do
        _(evaluate("1 = 1")).must_equal true
        _(evaluate("1 = 2")).must_equal false

        _(evaluate(' "a" = "a" ')).must_equal true
        _(evaluate(' "a" = "b" ')).must_equal false

        _(evaluate(' @"P1D" = @"P1D" ')).must_equal true
        _(evaluate(' @"P1D" = @"P2D" ')).must_equal false
      end

      it "should compare a value with null" do
        _(evaluate("1 = null")).must_equal false
        _(evaluate(' "a" = null ')).must_equal false
        _(evaluate(' @"P1D" = null ')).must_equal false
      end

      it "should compare two null values" do
        _(evaluate("null = null")).must_equal true
      end

      it "should return null if the values have a different type" do
        _(evaluate("1 = true")).must_be_nil
        _(evaluate(' 1 = "a" ')).must_be_nil
        _(evaluate(' 1 = @"P1D" ')).must_be_nil
      end
    end

    describe "A comparison operator" do
      it "should compare two values of the same type" do
        _(evaluate("1 < 2")).must_equal true
        _(evaluate("1 > 3")).must_equal false

        _(evaluate(' @"P1D" < @"P2D" ')).must_equal true
        _(evaluate(' @"P1D" > @"P3D" ')).must_equal false
      end

      it "should return null if a value is null" do
        _(evaluate("1 < null")).must_be_nil
        _(evaluate(' @"P1D" > null ')).must_be_nil
      end

      it "should return null if the values are null" do
        _(evaluate("null < null")).must_be_nil
      end

      it "should return null if the values have a different type" do
        _(evaluate("1 < true")).must_be_nil
        _(evaluate(' 1 > @"P1D" ')).must_be_nil
      end
    end

    describe "An unary-test equal operator" do
      it "should compare two values of the same type" do
        _(FEEL.test(1, "1")).must_equal true
        _(FEEL.test(2, "1")).must_equal false

        _(FEEL.test("a", ' "a" ')).must_equal true
        _(FEEL.test("b", ' "a" ')).must_equal false
      end

      it "should compare a value with null" do
        _(FEEL.test(nil, "1")).must_equal false
        _(FEEL.test(nil, ' "a" ')).must_equal false
      end

      it "should compare two null values" do
        _(FEEL.test(nil, "null")).must_equal true
      end

      it "should return null if the values have a different type" do
        _(FEEL.test(true, "1")).must_equal false
        _(FEEL.test("a", "1")).must_equal false
      end
    end

    describe "An unary-test operator" do
      it "should compare two values of the same type" do
        _(FEEL.test(1, "< 2")).must_equal true
        _(FEEL.test(1, "> 3")).must_equal false
      end

      it "should return null if the input value is null" do
        _(FEEL.test(nil, "< 2")).must_equal false
      end

      it "should return null if the values have a different type" do
        _(FEEL.test(true, "< 1")).must_equal false
        _(FEEL.test("a", "> 1")).must_equal false
      end
    end
  end
end
