# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterFunctionTest
module FEEL
  describe "function definitions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    def function(text)
      FEEL.evaluate(text)
    end

    it "should be returned as a function" do
      fn = function("function(x) x + 1")
      _(fn).must_be_kind_of FEEL::Function
      _(fn.params).must_equal ["x"]
      _(fn.call(1)).must_equal 2
    end

    it "should invoke a function without parameters" do
      _(evaluate("f()", f: function('function() "invoked"'))).must_equal "invoked"
    end

    it "should invoke a function with a positional parameter" do
      f = function("function(x) x + 1")
      _(evaluate("f(1)", f: f)).must_equal 2
      _(evaluate("f(2)", f: f)).must_equal 3
    end

    it "should invoke a function with positional parameters" do
      add = function("function(x,y) x + y")
      _(evaluate("add(1,2)", add: add)).must_equal 3
      _(evaluate("add(2,3)", add: add)).must_equal 5
    end

    it "should invoke a function with a named parameter" do
      f = function("function(x) x + 1")
      _(evaluate("f(x:1)", f: f)).must_equal 2
      _(evaluate("f(x:2)", f: f)).must_equal 3
    end

    it "should invoke a function with named parameters" do
      sub = function("function(x,y) x - y")
      _(evaluate("sub(x:4,y:2)", sub: sub)).must_equal 2
      _(evaluate("sub(y:2,x:4)", sub: sub)).must_equal 2
    end

    it "should take an expression as parameter" do
      _(evaluate("f(2 + 3)", f: function("function(x) x + 1"))).must_equal 6
    end

    it "should take another function as parameter" do
      a = function("function(x) x + 1")
      b = function("function(x) x + 2")
      _(evaluate("a(b(1))", a: a, b: b)).must_equal 4
    end

    it "should return null if invoked with wrong parameters" do
      f = function("function(x,y) true")
      _(evaluate("f()", f: f)).must_be_nil
      _(evaluate("f(1)", f: f)).must_be_nil
      _(evaluate("f(x:1,z:3)", f: f)).must_be_nil
      _(evaluate("f(x:1,y:2,z:3)", f: f)).must_be_nil
    end

    it "should return null if no function exists with the name" do
      _(evaluate("f()")).must_be_nil
      _(evaluate("f()", x: "a variable")).must_be_nil
    end

    it "should replace not set parameters with null" do
      f = function(<<~FEEL)
        function(x,y)
          if x = null
          then "x"
          else if y = null
          then "y"
          else "ok"
      FEEL
      _(evaluate("f(x:1)", f: f)).must_equal "y"
      _(evaluate("f(y:1)", f: f)).must_equal "x"
      _(evaluate("f(x:1,y:1)", f: f)).must_equal "ok"
    end

    it "should invoke a function with a named parameter containing whitespaces" do
      f = function("function(test name) `test name` + 1")
      _(evaluate("f(test name:1)", f: f)).must_equal 2
      _(evaluate("f(test name:2)", f: f)).must_equal 3
    end

    it "should invoke a function with a named parameter containing more than one whitespace" do
      f = function("function(test   name yada) `test name yada` + 1")
      _(evaluate("f(test   name yada:1)", f: f)).must_equal 2
    end

    it "should invoke built-in functions with named parameters" do
      _(evaluate('substring before(string: "Hello world", match: "world")')).must_equal "Hello "
    end

    it "should be defined and invoked in a context" do
      _(evaluate("{add: function(a, b) a + b, result: add(1, 2)}.result")).must_equal 3
      _(evaluate("{add: function(a, b) a + b}.add(2, 3)")).must_equal 5
    end

    it "should be invoked directly" do
      _(evaluate("(function(x) x * 2)(21)")).must_equal 42
    end

    it "should support recursion within a context" do
      _(evaluate("{fact: function(n) if n <= 1 then 1 else n * fact(n - 1), result: fact(5)}.result")).must_equal 120
    end

    it "should capture variables of the defining context" do
      _(evaluate("{factor: 3, scale: function(x) x * factor}.scale(2)")).must_equal 6
      _(evaluate("for i in [1, 2] return {f: function(x) x + i}.f(10)")).must_equal [11, 12]
    end

    it "should support typed parameters" do
      _(evaluate("(function(x: number, y: number) x + y)(1, 2)")).must_equal 3
    end

    it "should be passed to built-in functions" do
      _(evaluate("sort([3, 1, 4, 2], function(x, y) x < y)")).must_equal [1, 2, 3, 4]
      _(evaluate("sort([3, 1, 4, 2], function(x, y) x > y)")).must_equal [4, 3, 2, 1]
    end

    it "should be invocable from ruby" do
      fn = function("function(a, b) a * b")
      _(fn.call(6, 7)).must_equal 42
      _(fn.call_named("b" => 2, "a" => 5)).must_equal 10
    end

    it "should not report parameters as variables" do
      _(LiteralExpression.new(text: "function(x) x + y").named_variables).must_equal ["y"]
    end
  end
end
