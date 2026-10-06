# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterBooleanExpressionTest
module FEEL
  describe "interpreter boolean expression" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A boolean" do
      it "should compare with '='" do
        _(evaluate("true = true")).must_equal true
        _(evaluate("true = false")).must_equal false
      end

      it "should compare with null" do
        _(evaluate(" true = null ")).must_equal false
        _(evaluate(" null = false ")).must_equal false
        _(evaluate(" true != null ")).must_equal true
        _(evaluate(" null != false ")).must_equal true
      end

      it "should be in conjunction" do
        _(evaluate("true and true")).must_equal true
        _(evaluate("true and false")).must_equal false

        _(evaluate("true and true and false")).must_equal false

        _(evaluate("true and 2")).must_be_nil
        _(evaluate("false and 2")).must_equal false

        _(evaluate("2 and true")).must_be_nil
        _(evaluate("2 and false")).must_equal false

        _(evaluate("2 and 4")).must_be_nil
      end

      it "should be in conjunction with between" do
        _(evaluate("1 between 1 and 3 and 2 between 1 and 3")).must_equal true
      end

      it "should be in conjunction with some/every-expression" do
        _(evaluate(" (10 > 5) and (some y in [1,2,3] satisfies y > 2) ")).must_equal true

        _(evaluate(" (some y in [1,2,3] satisfies y > 2) and (10 > 5) ")).must_equal true

        _(evaluate(" (some y in [1,2,3] satisfies y > 2) and (every x in [1,2,3] satisfies x < 5) ")).must_equal true
      end

      it "should be in conjunction (with parentheses)" do
        _(evaluate("x and (y)", x: true, y: false)).must_equal false

        _(evaluate("(x) and y", x: true, y: false)).must_equal false
      end

      it "should be in disjunction" do
        _(evaluate("false or true")).must_equal true
        _(evaluate("false or false")).must_equal false

        _(evaluate("false or false or true")).must_equal true

        _(evaluate("true or 2")).must_equal true
        _(evaluate("false or 2")).must_be_nil

        _(evaluate("2 or true")).must_equal true
        _(evaluate("2 or false")).must_be_nil

        _(evaluate("2 or 4")).must_be_nil
      end

      it "should be in disjunction (with parentheses)" do
        _(evaluate("x or (y)", x: false, y: true)).must_equal true

        _(evaluate("(x) or y", x: false, y: true)).must_equal true
      end

      it "should be in disjunction with comparison" do
        _(evaluate("1 = 1 or 1 = 2")).must_equal true
      end

      it "should be in conjunction and disjunction" do
        _(evaluate("true and false or true and true")).must_equal true
      end

      it "should negate" do
        _(evaluate("not(true)")).must_equal false
        _(evaluate("not(false)")).must_equal true

        _(evaluate("not(2)")).must_be_nil
      end
    end
  end
end
