# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterNonExistingVariableExpressionTest
#
# Note: suppressed failures (reportFailure) are not supported, only the result
# is checked.
module FEEL
  describe "interpreter non-existing variable expression" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A non-existing variable" do
      it "should compare with '='" do
        _(evaluate("x = 1")).must_equal false
        _(evaluate("1 = x")).must_equal false
        _(evaluate("x = true")).must_equal false
        _(evaluate("true = x")).must_equal false
        _(evaluate(' x = "string" ')).must_equal false
        _(evaluate(' "string" = x ')).must_equal false

        _(evaluate("x = null")).must_equal true
        _(evaluate("null = x")).must_equal true
        _(evaluate("x = y")).must_equal true
      end

      it "should compare with `<`" do
        _(evaluate("x < 1")).must_be_nil
        _(evaluate("1 < x")).must_be_nil
        _(evaluate("x < true")).must_be_nil
        _(evaluate("true < x")).must_be_nil
        _(evaluate(' x < "string" ')).must_be_nil
        _(evaluate(' "string" < x ')).must_be_nil
        _(evaluate("x < null")).must_be_nil
        _(evaluate("null < x")).must_be_nil
        _(evaluate("x < y")).must_be_nil
      end

      it "should compare with `>`" do
        _(evaluate("x > 1")).must_be_nil
        _(evaluate("1 > x")).must_be_nil
        _(evaluate("x > true")).must_be_nil
        _(evaluate("true > x")).must_be_nil
        _(evaluate(' x > "string" ')).must_be_nil
        _(evaluate(' "string" > x ')).must_be_nil
        _(evaluate("x > null")).must_be_nil
        _(evaluate("null > x")).must_be_nil
        _(evaluate("x > y")).must_be_nil
      end

      it "should compare with `<=`" do
        _(evaluate("x <= 1")).must_be_nil
        _(evaluate("1 <= x")).must_be_nil
        _(evaluate("x <= true")).must_be_nil
        _(evaluate("true <= x")).must_be_nil
        _(evaluate(' x <= "string" ')).must_be_nil
        _(evaluate(' "string" <= x ')).must_be_nil
        _(evaluate("x <= null")).must_be_nil
        _(evaluate("null <= x")).must_be_nil
        _(evaluate("x <= y")).must_be_nil
      end

      it "should compare with `>=`" do
        _(evaluate("x >= 1")).must_be_nil
        _(evaluate("1 >= x")).must_be_nil
        _(evaluate("x >= true")).must_be_nil
        _(evaluate("true >= x")).must_be_nil
        _(evaluate(' x >= "string" ')).must_be_nil
        _(evaluate(' "string" >= x ')).must_be_nil
        _(evaluate("x >= null")).must_be_nil
        _(evaluate("null >= x")).must_be_nil
        _(evaluate("x >= y")).must_be_nil
      end

      it "should compare with `between _ and _`" do
        _(evaluate("x between 1 and 3")).must_be_nil
        _(evaluate("1 between x and 3")).must_be_nil
        _(evaluate("3 between 1 and x")).must_be_nil
        _(evaluate("x between y and 3")).must_be_nil
        _(evaluate("x between 1 and y")).must_be_nil
        _(evaluate("x between y and z")).must_be_nil
      end

      it "should return null" do
        _(evaluate("non_existing")).must_be_nil
      end
    end

    describe "A non-existing input value" do
      it "should be equal to null" do
        _(FEEL.test(nil, "null")).must_equal true
      end

      it "should not be equal to a non-null value" do
        _(FEEL.test(nil, "2")).must_equal false
      end

      it "should not compare to a non-null value" do
        # null result = no match
        _(FEEL.test(nil, "< 2")).must_equal false
      end
    end
  end
end
