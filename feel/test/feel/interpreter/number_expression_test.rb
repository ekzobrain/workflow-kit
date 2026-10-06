# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterNumberExpressionTest
module FEEL
  describe "number expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A number" do
      it "should add to '4'" do
        _(evaluate("2+4")).must_equal 6
      end

      it "should add to '4' and '6'" do
        _(evaluate("2+4+6")).must_equal 12
      end

      it "should add to not-a-number" do
        _(evaluate("2 + true")).must_be_nil
        _(evaluate("false + 3")).must_be_nil
      end

      it "should subtract from '2'" do
        _(evaluate("4-2")).must_equal 2
      end

      it "should subtract to not-a-number" do
        _(evaluate("2 - true")).must_be_nil
        _(evaluate("false - 3")).must_be_nil
      end

      it "should add and subtract" do
        _(evaluate("2+4-3+1")).must_equal 4
      end

      it "should multiply by '3'" do
        _(evaluate("3*3")).must_equal 9
      end

      it "should multiply to not-a-number" do
        _(evaluate("2 * true")).must_be_nil
        _(evaluate("false * 3")).must_be_nil
      end

      it "should divide by '4'" do
        _(evaluate("8/4")).must_equal 2
      end

      it "should be null if divide by zero" do
        _(evaluate("2 / 0")).must_be_nil
      end

      it "should divide to not-a-number" do
        _(evaluate("2 / true")).must_be_nil
        _(evaluate("false / 3")).must_be_nil
      end

      it "should multiply and divide" do
        _(evaluate("3*4/2*5")).must_equal 30
      end

      it "should exponentiate by '3'" do
        _(evaluate("2**3")).must_equal 8
      end

      it "should exponentiate twice" do
        # all operators are left associative
        _(evaluate("2**2**3")).must_equal 64
      end

      it "should exponentiate by '3.1'" do
        _(evaluate("2**3.1")).must_equal 8.574187700290345
      end

      it "should negate" do
        _(evaluate("-2")).must_equal(-2)
      end

      it "should negate and multiply" do
        _(evaluate("2 * -3")).must_equal(-6)
      end

      it "should add and multiply" do
        _(evaluate("2 + 3 * 4")).must_equal 14

        _(evaluate("2 * 3 + 4")).must_equal 10
      end

      it "should multiply and exponentiate" do
        _(evaluate("2**3 * 4")).must_equal 32

        _(evaluate("3 * 4**2")).must_equal 48
      end

      it "should compare with '='" do
        _(evaluate("x=2", x: 2)).must_equal true
        _(evaluate("x=2", x: 3)).must_equal false

        _(evaluate("(x * 2) = 4", x: 2)).must_equal true
        _(evaluate("(x * 2) = 4", x: 3)).must_equal false

        _(evaluate("x = -1", x: -1)).must_equal true
        _(evaluate("x = -1", x: 1)).must_equal false
      end

      it "should compare with '!='" do
        _(evaluate("x!=2", x: 2)).must_equal false
        _(evaluate("x!=2", x: 3)).must_equal true
      end

      it "should compare with '<'" do
        _(evaluate("x<2", x: 1)).must_equal true
        _(evaluate("x<2", x: 2)).must_equal false
      end

      it "should compare with '<='" do
        _(evaluate("x<=2", x: 2)).must_equal true
        _(evaluate("x<=2", x: 3)).must_equal false
      end

      it "should compare with '>'" do
        _(evaluate("x>2", x: 2)).must_equal false
        _(evaluate("x>2", x: 3)).must_equal true
      end

      it "should compare with '>='" do
        _(evaluate("x>=2", x: 2)).must_equal true
        _(evaluate("x>=2", x: 1)).must_equal false
      end

      it "should compare with null" do
        _(evaluate("2 = null")).must_equal false
        _(evaluate("null = 2")).must_equal false
        _(evaluate("null != 2")).must_equal true

        _(evaluate("2 > null")).must_be_nil
        _(evaluate("null < 2")).must_be_nil
      end

      it "should compare null with 'in' operator" do
        _(evaluate("null in < 2")).must_be_nil
        _(evaluate("null in (2..4)")).must_be_nil
      end

      it "should compare with 'between _ and _'" do
        _(evaluate("x between 2 and 4", x: 1)).must_equal false
        _(evaluate("x between 2 and 4", x: 2)).must_equal true
        _(evaluate("x between 2 and 4", x: 3)).must_equal true
        _(evaluate("x between 2 and 4", x: 4)).must_equal true
        _(evaluate("x between 2 and 4", x: 5)).must_equal false
      end

      it "should compare with 'in'" do
        _(evaluate("x in < 2", x: 1)).must_equal true
        _(evaluate("x in < 2", x: 2)).must_equal false

        _(evaluate("x in (2,4,6)", x: 4)).must_equal true
        _(evaluate("x in (2,4,6)", x: 5)).must_equal false
      end

      it "should compare with 'in' with interval (..)" do
        _(evaluate("x in (2 .. 4)", x: 3)).must_equal true
        _(evaluate("x in (2 .. 4)", x: 4)).must_equal false

        _(evaluate("3 in (2..4)")).must_equal true
        _(evaluate("4 in (2..4)")).must_equal false
      end

      it "should compare with 'in' with interval [..]" do
        _(evaluate("3 in [2 .. 4]")).must_equal true
        _(evaluate("4 in [2 .. 4]")).must_equal true
      end

      it "should compare with 'in' (multiple positive tests)" do
        _(evaluate("5 in (< 3, >= 5)")).must_equal true
      end

      it "should compare multiplication with 'in'" do
        _(evaluate("2 * 3 in > 3")).must_equal true
      end

      it "should be null if nAn" do
        _(evaluate("x", x: Float::NAN)).must_be_nil
      end

      it "should be null if infinity" do
        _(evaluate("x", x: Float::INFINITY)).must_be_nil
        _(evaluate("x", x: -Float::INFINITY)).must_be_nil
      end
    end
  end
end
