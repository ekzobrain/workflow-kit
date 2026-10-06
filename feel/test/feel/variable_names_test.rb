# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: ExpressionVariableExtractorTest
#
# Mapping: `variableReferences` corresponds to `LiteralExpression#named_variables`
# (qualified names, e.g. "a.b"), `variableNames` to the top-level names of
# `named_variables` (e.g. "a").
module FEEL
  describe "variable names" do
    def parse_expression(text)
      LiteralExpression.new(text: text).tap { |expression| _(expression.valid?).must_equal true }
    end

    def parse_unary_tests(text)
      UnaryTests.new(text: text).tap { |unary_tests| _(unary_tests.valid?).must_equal true }
    end

    def variable_names(parse_result)
      parse_result.named_variables.map { |name| name.split(".").first }.to_set
    end

    def variable_references(parse_result)
      parse_result.named_variables.to_set
    end

    describe "The variable names of a parsed expression" do
      it "should be empty if no variable is referenced" do
        _(variable_names(parse_expression("1 + 2"))).must_be_empty
      end

      it "should contain the name of a single variable" do
        _(variable_names(parse_expression("a"))).must_equal Set["a"]
      end

      it "should contain the names of all variables" do
        _(variable_names(parse_expression("a < b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of the variables only once" do
        _(variable_names(parse_expression("a + a + b"))).must_equal Set["a", "b"]
      end

      it "should contain the top-level names of nested variables" do
        _(variable_names(parse_expression("a.b < c.d"))).must_equal Set["a", "c"]
      end

      it "should contain the names of variables in a list" do
        _(variable_names(parse_expression("[a, b]"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in a context" do
        _(variable_names(parse_expression("{a: c, b: d}"))).must_equal Set["c", "d"]
      end

      it "should not contain the names of nested context entries" do
        _(variable_names(parse_expression("{a: c, b: a + d}"))).must_equal Set["c", "d"]
      end

      it "should not contain the names of nested context entries (level 2)" do
        _(variable_names(parse_expression("{a: c, b: {d: a + e}}"))).must_equal Set["c", "e"]
      end

      it "should contain the names of variables in a range" do
        _(variable_names(parse_expression("[a..b)"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in a comparison" do
        _(variable_names(parse_expression("a < b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in an addition" do
        _(variable_names(parse_expression("a + b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in an subtraction" do
        _(variable_names(parse_expression("a - b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in an multiplication" do
        _(variable_names(parse_expression("a * b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in an division" do
        _(variable_names(parse_expression("a / b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in an exponentiation" do
        _(variable_names(parse_expression("a ** b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in an arithmetic negation" do
        _(variable_names(parse_expression("- a"))).must_equal Set["a"]
      end

      it "should contain the names of variables in a disjunction" do
        _(variable_names(parse_expression("a or b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in a conjunction" do
        _(variable_names(parse_expression("a and b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in 'if _ then _ else _'" do
        _(variable_names(parse_expression("if a < 5 then b else c"))).must_equal Set["a", "b", "c"]
      end

      it "should contain the names of variables in '_ in _'" do
        _(variable_names(parse_expression("a in (0..b)"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in 'some _ in _ satisfies _'" do
        _(variable_names(parse_expression("some x in [a] satisfies x < b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in 'every _ in _ satisfies _'" do
        _(variable_names(parse_expression("every x in [a] satisfies x < b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in 'for _ in _ return _'" do
        _(variable_names(parse_expression("for x in [a] return x + b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in a list filter" do
        _(variable_names(parse_expression("[1, 2][item < a]"))).must_equal Set["a"]
      end

      it "should not contain the names of context entries in a context list filter" do
        _(variable_names(parse_expression("[{a: b}][a < c]"))).must_equal Set["b", "c"]
      end

      it "should contain the names of variables in path expression" do
        _(variable_names(parse_expression("{a: b}.a"))).must_equal Set["b"]
      end

      it "should contain the names of variables in '_ instance of _'" do
        _(variable_names(parse_expression("a instance of string"))).must_equal Set["a"]
      end

      it "should contain the names of variables in function invocation with positional arguments" do
        _(variable_names(parse_expression("ceiling(a)"))).must_equal Set["a"]
      end

      it "should contain the names of variables in function invocation with named arguments" do
        _(variable_names(parse_expression("ceiling(n: a)"))).must_equal Set["a"]
      end

      it "should contain the names of variables in function definition" do
        _(variable_names(parse_expression("function(a) a + b"))).must_equal Set["b"]
      end
    end

    describe "The variable names of a parsed unary-test expression" do
      it "should contain the names of variables in comparison" do
        _(variable_names(parse_unary_tests("< a"))).must_equal Set["a"]
      end

      it "should contain the names of variables in a disjunction" do
        _(variable_names(parse_unary_tests("a, b"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in a negation" do
        _(variable_names(parse_unary_tests("not(a, b)"))).must_equal Set["a", "b"]
      end

      it "should contain the names of variables in a boolean expression" do
        _(variable_names(parse_unary_tests("contains(?, a), ends with(?, b)"))).must_equal Set["a", "b"]
      end
    end

    describe "The variable references of a parsed expression" do
      it "should be empty if no variable is referenced" do
        _(variable_references(parse_expression("1 + 2"))).must_be_empty
      end

      it "should contain all top-level variables" do
        _(variable_references(parse_expression("a + b + c"))).must_equal Set["a", "b", "c"]
      end

      it "should contain all nested variables" do
        _(variable_references(parse_expression("a.b + a.c + d.e"))).must_equal Set["a.b", "a.c", "d.e"]
      end

      it "should contain top-level and nested variables" do
        _(variable_references(parse_expression("a + b.c + b.d"))).must_equal Set["a", "b.c", "b.d"]
      end

      it "should contain all variables only once" do
        _(variable_references(parse_expression("a + a + b.c + b.c"))).must_equal Set["a", "b.c"]
      end

      it "should contain all variables from context" do
        _(variable_references(parse_expression("{a: b, c: d.e, f: {g: h.i}}"))).must_equal Set["b", "d.e", "h.i"]
      end
    end
  end
end
