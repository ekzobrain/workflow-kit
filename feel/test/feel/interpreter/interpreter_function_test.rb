# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterFunctionTest
#
# Note: suppressed failures (reportFailure) are not supported, only the result
# is checked. Functions are passed as variables.
module FEEL
  describe "interpreter function" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    def evaluate_function(text)
      FEEL.evaluate(text).tap { |function| _(function).must_be_kind_of FEEL::Function }
    end

    describe "A function definition" do
      it "should be returned as a function" do
        function = evaluate_function("function(x) x + 1")

        _(function.params).must_equal ["x"]
      end
    end

    describe "A function invocation" do
      it "should invoke a function without parameter" do
        _(evaluate("f()", f: evaluate_function(' function() "invoked" '))).must_equal "invoked"
      end

      it "should invoke a function with a positional parameter" do
        functions = { f: evaluate_function("function(x) x + 1") }

        _(evaluate("f(1)", functions)).must_equal 2

        _(evaluate("f(2)", functions)).must_equal 3
      end

      it "should invoke a function with positional parameters" do
        functions = { add: evaluate_function("function(x,y) x + y") }

        _(evaluate("add(1,2)", functions)).must_equal 3

        _(evaluate("add(2,3)", functions)).must_equal 5
      end

      it "should invoke a function a named parameter" do
        functions = { f: evaluate_function("function(x) x + 1") }

        _(evaluate("f(x:1)", functions)).must_equal 2

        _(evaluate("f(x:2)", functions)).must_equal 3
      end

      it "should invoke a function with named parameters" do
        functions = { sub: evaluate_function("function(x,y) x - y") }

        _(evaluate("sub(x:4,y:2)", functions)).must_equal 2

        _(evaluate("sub(y:2,x:4)", functions)).must_equal 2
      end

      it "should take an expression as parameter" do
        _(evaluate("f(2 + 3)", f: evaluate_function("function(x) x + 1"))).must_equal 6
      end

      it "should take another function as parameter" do
        functions = {
          a: evaluate_function("function(x) x + 1"),
          b: evaluate_function("function(x) x + 2"),
        }

        _(evaluate("a(b(1))", functions)).must_equal 4
      end

      it "should return null if invoked with wrong parameters" do
        functions = { f: evaluate_function("function(x,y) true") }

        _(evaluate("f()", functions)).must_be_nil

        _(evaluate("f(1)", functions)).must_be_nil

        _(evaluate("f(x:1,z:3)", functions)).must_be_nil

        _(evaluate("f(x:1,y:2,z:3)", functions)).must_be_nil
      end

      it "should return null if no function exists with the name" do
        _(evaluate("f()")).must_be_nil
      end

      it "should return null if the name doesn't resolve to a function" do
        _(evaluate("f()", x: "a variable")).must_be_nil
      end

      it "should return null for a built-in function if invoked with wrong arguments" do
        _(evaluate("number(null)")).must_be_nil
      end

      it "should replace not set parameters with null" do
        functions = { f: evaluate_function(<<~FEEL) }
          function(x,y)
            if x = null
            then "x"
            else if y = null
            then "y"
            else "ok"
        FEEL

        _(evaluate("f(x:1)", functions)).must_equal "y"

        _(evaluate("f(y:1)", functions)).must_equal "x"

        _(evaluate("f(x:1,y:1)", functions)).must_equal "ok"
      end

      it "should be followed by a path" do
        _(evaluate(" date(2019,09,17).year ")).must_equal 2019
      end

      it "should be followed by a filter" do
        _(evaluate(" index of([1,2,3,2],2)[1]  ")).must_equal 2
      end

      it "should invoke a function with parameters contain whitespaces" do
        _(evaluate('number(from: "1.000.000,01", decimal separator:",", grouping separator:".")')).must_equal 1_000_000.01
      end

      it "should invoke a function with a named parameter containing whitespaces" do
        functions = { f: evaluate_function("function(test name) `test name` + 1") }

        _(evaluate("f(test name:1)", functions)).must_equal 2

        _(evaluate("f(test name:2)", functions)).must_equal 3
      end

      it "should invoke a function with a named parameter containing more than one whitespace" do
        functions = { f: evaluate_function("function(test   name yada) `test   name yada` + 1") }

        _(evaluate("f(test   name yada:1)", functions)).must_equal 2

        _(evaluate("f(test   name yada:2)", functions)).must_equal 3
      end
    end
  end
end
