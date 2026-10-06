# frozen_string_literal: true

require "test_helper"

module FEEL
  describe "compiled expressions" do
    before do
      FEEL.clear_expression_cache
    end

    after do
      FEEL.config.expression_cache_size = Configuration::DEFAULT_EXPRESSION_CACHE_SIZE
    end

    describe :compile do
      it "should evaluate a compiled expression with different variables" do
        expression = FEEL.compile("a + b")
        _(expression.evaluate(a: 1, b: 2)).must_equal 3
        _(expression.evaluate("a" => 10, "b" => 20)).must_equal 30
        _(expression.evaluate(a: "x", b: "y")).must_equal "xy"
        _(expression.evaluate(a: date = Date.new(2020, 1, 1), b: 1.day)).must_equal date + 1
        _(expression.evaluate(a: 1)).must_be_nil
      end

      it "should cache compiled expressions by text" do
        _(FEEL.compile("a + b")).must_be_same_as FEEL.compile("a + b")
        _(FEEL.compile("a + b")).wont_be_same_as FEEL.compile("a - b")
        _(FEEL.expression_cache.size).must_equal 2
      end

      it "should raise a syntax error for invalid expressions" do
        _ { FEEL.compile("1 +") }.must_raise SyntaxError
        _ { FEEL.compile("1 +") }.must_raise SyntaxError
        _ { FEEL.evaluate("1 +") }.must_raise SyntaxError
      end

      it "should cache unary tests separately from expressions" do
        tests = FEEL.compile_test("< 10")
        _(tests).must_be_same_as FEEL.compile_test("< 10")
        _(tests.test(5)).must_equal true
        _(tests.test(15)).must_equal false
        _(FEEL.compile("1").evaluate).must_equal 1
        _(FEEL.compile_test("1").test(1)).must_equal true
        _ { FEEL.compile_test("[1..") }.must_raise SyntaxError
      end

      it "should evict the least recently used expressions" do
        FEEL.config.expression_cache_size = 2
        first = FEEL.compile("1")
        FEEL.compile("2")
        FEEL.compile("1")
        FEEL.compile("3")
        _(FEEL.expression_cache.size).must_equal 2
        _(FEEL.compile("1")).must_be_same_as first
      end

      it "should not cache when the cache is disabled" do
        FEEL.config.expression_cache_size = 0
        _(FEEL.compile("a")).wont_be_same_as FEEL.compile("a")
        _(FEEL.evaluate("a + 1", variables: { a: 1 })).must_equal 2
      end
    end

    describe :variables do
      it "should prefer variables over functions" do
        _(FEEL.evaluate("sum(1, 2)", variables: { sum: ->(a, b) { a * b } })).must_equal 2
        FEEL.config.functions = { "sum" => ->(a, b) { a - b } }
        _(FEEL.evaluate("sum(1, 2)")).must_equal(-1)
        _(FEEL.evaluate("sum(1, 2)", variables: { "sum" => ->(a, b) { a * b } })).must_equal 2
      end

      it "should use custom functions changed after compiling" do
        expression = FEEL.compile("f(1)")
        FEEL.config.functions = { f: ->(x) { x + 1 } }
        _(expression.evaluate).must_equal 2
        FEEL.config.functions[:f] = ->(x) { x + 2 }
        _(expression.evaluate).must_equal 3
      end

      it "should not modify the variables" do
        variables = { a: 1, list: [3, 1, 2], context: { x: 1 } }
        FEEL.evaluate("{a: 2, b: sort(list), c: context put(context, \"y\", 2)}", variables: variables)
        _(variables).must_equal({ a: 1, list: [3, 1, 2], context: { x: 1 } })
      end

      it "should return results that can be modified without affecting the expression" do
        expression = FEEL.compile('"Hello"')
        expression.evaluate << " World"
        _(expression.evaluate).must_equal "Hello"
      end
    end

    describe :threads do
      it "should evaluate expressions concurrently" do
        expressions = (1..20).map { |i| "a * #{i} + b" }
        results = (1..8).map do |thread|
          Thread.new do
            (1..200).map do |i|
              text = expressions[i % expressions.size]
              [FEEL.evaluate(text, variables: { a: i, b: thread }), (i * ((i % expressions.size) + 1)) + thread]
            end
          end
        end.flat_map(&:value)
        _(results.all? { |actual, expected| actual == expected }).must_equal true
      end
    end
  end
end
