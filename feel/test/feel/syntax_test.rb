# frozen_string_literal: true

require "test_helper"

# Ruby-specific syntax tests that are not covered by the ported feel-scala
# tests (see test/feel/interpreter/interpreter_expression_test.rb).
module FEEL
  describe "syntax" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe :comments do
      it "should support comments between tokens" do
        _(evaluate(<<~FEEL)).must_equal 6
          1 + // one
          2 /* two */ + 3 // three
        FEEL
      end

      it "should not treat comment markers in strings as comments" do
        _(evaluate('"http://example.com"')).must_equal "http://example.com"
        _(evaluate('"/* not a comment */"')).must_equal "/* not a comment */"
      end

      it "should support comments in unary tests" do
        _(FEEL.test(5, "< 10 // less than ten")).must_equal true
        _(FEEL.test(5, "/* range */ [1..3], [4..6]")).must_equal true
      end
    end

    describe :names do
      it "should support names with whitespaces in context keys" do
        _(evaluate("{first name: \"John\"}.`first name`")).must_equal "John"
      end
    end

    describe :arithmetic do
      it "should divide integers without truncating" do
        _(evaluate("7 / 2")).must_equal 3.5
        _(evaluate("6 / 2")).must_equal 3
      end

      it "should return null when dividing by zero" do
        _(evaluate("1 / 0")).must_be_nil
      end

      it "should return null for invalid operand types" do
        _(evaluate('"a" * 3')).must_be_nil
        _(evaluate('"a" + 1')).must_be_nil
        _(evaluate("[1] + [2]")).must_be_nil
        _(evaluate('-"a"')).must_be_nil
      end

      it "should negate variables and durations" do
        _(evaluate("-x", x: 5)).must_equal(-5)
        _(evaluate("- x + 10", x: 5)).must_equal 5
        _(evaluate('-duration("P1D")')).must_equal(-1.day)
      end

      it "should subtract dates" do
        _(evaluate('date("2020-01-10") - date("2020-01-01")')).must_equal 9.days
      end
    end

    describe :named_variables do
      it "should not report variables bound by for, quantified and filter expressions" do
        _(LiteralExpression.new(text: "for x in xs return x * factor").named_variables).must_equal %w[xs factor]
        _(LiteralExpression.new(text: "some x in xs satisfies x > limit").named_variables).must_equal %w[xs limit]
        _(LiteralExpression.new(text: "orders[item.total > min].id").named_variables).must_equal %w[orders min]
      end

      it "should report functions with whitespaces in the name" do
        _(LiteralExpression.new(text: 'string length("abc") + count([1])').named_functions).must_equal ["string length", "count"]
      end

      it "should report the path of a qualified function invocation" do
        _(LiteralExpression.new(text: "a.b.f(x)").named_variables).must_equal %w[a.b x]
      end
    end
  end
end
