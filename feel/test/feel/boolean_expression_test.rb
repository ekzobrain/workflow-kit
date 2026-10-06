# frozen_string_literal: true

require "test_helper"

# Boolean expression tests that are not covered by the ported feel-scala tests
# (see test/feel/interpreter/interpreter_boolean_expression_test.rb).
module FEEL
  describe "boolean expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe :conjunction do
      it "should use ternary logic" do
        _(evaluate("true and null and true")).must_be_nil
        _(evaluate("true and false and null")).must_equal false
      end

      it "should combine with comparisons" do
        _(evaluate("x > 1 and x < 5", x: 3)).must_equal true
        _(evaluate("x > 1 and x < 5", x: 7)).must_equal false
      end
    end

    describe :disjunction do
      it "should use ternary logic" do
        _(evaluate("true or false or null")).must_equal true
        _(evaluate("false or null or false")).must_be_nil
      end
    end

    describe :precedence do
      it "should bind conjunction stronger than disjunction" do
        _(evaluate("true or false and false")).must_equal true
        _(evaluate("(true or false) and false")).must_equal false
      end
    end

    describe :if_expression do
      it "should evaluate the condition with a variable" do
        _(evaluate('if condition then "Eric" else "Eli"', condition: true)).must_equal "Eric"
        _(evaluate('if condition then "Eric" else "Eli"', condition: false)).must_equal "Eli"
      end

      it "should take the else branch if the condition is not a boolean" do
        _(evaluate("if 1 then 1 else 2")).must_equal 2
      end
    end
  end
end
