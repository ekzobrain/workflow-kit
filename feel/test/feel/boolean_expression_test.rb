# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterBooleanExpressionTest
module FEEL
  describe "boolean expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe :comparison do
      it "should compare with '='" do
        _(evaluate("true = true")).must_equal true
        _(evaluate("true = false")).must_equal false
      end

      it "should compare with null" do
        _(evaluate("true = null")).must_equal false
        _(evaluate("null = false")).must_equal false
        _(evaluate("true != null")).must_equal true
        _(evaluate("null != false")).must_equal true
      end
    end

    describe :conjunction do
      it "should evaluate conjunctions" do
        _(evaluate("true and true")).must_equal true
        _(evaluate("true and false")).must_equal false
        _(evaluate("true and true and false")).must_equal false
      end

      it "should use ternary logic" do
        _(evaluate("true and 2")).must_be_nil
        _(evaluate("false and 2")).must_equal false
        _(evaluate("2 and true")).must_be_nil
        _(evaluate("2 and false")).must_equal false
        _(evaluate("2 and 4")).must_be_nil
        _(evaluate("true and null and true")).must_be_nil
        _(evaluate("true and false and null")).must_equal false
      end

      it "should combine with between" do
        _(evaluate("1 between 1 and 3 and 2 between 1 and 3")).must_equal true
      end

      it "should combine with some/every expressions" do
        _(evaluate("(10 > 5) and (some y in [1,2,3] satisfies y > 2)")).must_equal true
        _(evaluate("(some y in [1,2,3] satisfies y > 2) and (10 > 5)")).must_equal true
        _(evaluate("(some y in [1,2,3] satisfies y > 2) and (every x in [1,2,3] satisfies x < 5)")).must_equal true
      end

      it "should combine with parentheses" do
        _(evaluate("x and (y)", x: true, y: false)).must_equal false
        _(evaluate("(x) and y", x: true, y: false)).must_equal false
      end

      it "should combine with comparisons" do
        _(evaluate("x > 1 and x < 5", x: 3)).must_equal true
        _(evaluate("x > 1 and x < 5", x: 7)).must_equal false
      end
    end

    describe :disjunction do
      it "should evaluate disjunctions" do
        _(evaluate("false or true")).must_equal true
        _(evaluate("false or false")).must_equal false
        _(evaluate("false or false or true")).must_equal true
      end

      it "should use ternary logic" do
        _(evaluate("true or 2")).must_equal true
        _(evaluate("false or 2")).must_be_nil
        _(evaluate("2 or true")).must_equal true
        _(evaluate("2 or false")).must_be_nil
        _(evaluate("2 or 4")).must_be_nil
        _(evaluate("true or false or null")).must_equal true
        _(evaluate("false or null or false")).must_be_nil
      end

      it "should combine with parentheses" do
        _(evaluate("x or (y)", x: false, y: true)).must_equal true
        _(evaluate("(x) or y", x: false, y: true)).must_equal true
      end

      it "should combine with comparisons" do
        _(evaluate("1 = 1 or 1 = 2")).must_equal true
      end
    end

    describe :precedence do
      it "should bind conjunction stronger than disjunction" do
        _(evaluate("true and false or true and true")).must_equal true
        _(evaluate("true or false and false")).must_equal true
        _(evaluate("(true or false) and false")).must_equal false
      end
    end

    describe :negation do
      it "should negate" do
        _(evaluate("not(true)")).must_equal false
        _(evaluate("not(false)")).must_equal true
        _(evaluate("not(2)")).must_be_nil
      end
    end

    describe :if_expression do
      it "should evaluate the condition with a variable" do
        _(evaluate('if condition then "Eric" else "Eli"', condition: true)).must_equal "Eric"
        _(evaluate('if condition then "Eric" else "Eli"', condition: false)).must_equal "Eli"
      end

      it "should take the else branch if the condition is not a boolean" do
        _(evaluate('if x < 5 then "low" else "high"', x: "foo")).must_equal "high"
        _(evaluate("if 1 then 1 else 2")).must_equal 2
      end

      it "should support conjunctions and disjunctions in the condition" do
        _(evaluate("if true and true then 1 else 2")).must_equal 1
        _(evaluate("if false or true then 1 else 2")).must_equal 1
      end

      it "should support a path, a filter, an in-test and instance of in the condition" do
        _(evaluate("if {a: true}.a then 1 else 2")).must_equal 1
        _(evaluate("if [true][1] then 1 else 2")).must_equal 1
        _(evaluate("if 1 in < 5 then 1 else 2")).must_equal 1
        _(evaluate("if 1 instance of number then 1 else 2")).must_equal 1
      end

      it "should support function calls in the branches" do
        _(evaluate("if 7 > var then flatten(xs) else []", xs: [1, 2], var: 3)).must_equal [1, 2]
        _(evaluate("if false then var else flatten(xs)", xs: [1, 2], var: 3)).must_equal [1, 2]
      end
    end
  end
end
