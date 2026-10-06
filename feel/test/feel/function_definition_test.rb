# frozen_string_literal: true

require "test_helper"

# Function definition tests that are not covered by the ported feel-scala
# tests (see test/feel/interpreter/interpreter_function_test.rb).
module FEEL
  describe "function definitions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    def function(text)
      FEEL.evaluate(text)
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

    it "should return null if a ruby function raises an error" do
      _(evaluate("f(1)", f: ->(_x) { raise ArgumentError, "boom" })).must_be_nil
    end

    it "should not report parameters as variables" do
      _(LiteralExpression.new(text: "function(x) x + y").named_variables).must_equal ["y"]
    end
  end
end
