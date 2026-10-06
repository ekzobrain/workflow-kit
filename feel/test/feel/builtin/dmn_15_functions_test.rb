# frozen_string_literal: true

require "test_helper"

# Built-in functions of DMN 1.4/1.5 that feel-scala doesn't implement:
# is(), list replace(), range() and the properties of ranges.
module FEEL
  describe "DMN 1.5 built-in functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "is()" do
      it "should be true for the same values of the same type" do
        _(evaluate("is(1, 1)")).must_equal true
        _(evaluate("is(1, 1.0)")).must_equal true
        _(evaluate('is("a", "a")')).must_equal true
        _(evaluate("is(true, true)")).must_equal true
        _(evaluate("is(null, null)")).must_equal true
        _(evaluate('is(@"2012-12-25", @"2012-12-25")')).must_equal true
        _(evaluate('is(duration("P1Y"), duration("P12M"))')).must_equal true
        _(evaluate('is([1, date("2020-01-01")], [1, date("2020-01-01")])')).must_equal true
        _(evaluate("is({a: 1}, {a: 1})")).must_equal true
        _(evaluate("is(value1: 1, value2: 1)")).must_equal true
      end

      it "should be false for values of different types" do
        _(evaluate('is(1, "1")')).must_equal false
        _(evaluate("is(null, 1)")).must_equal false
        _(evaluate('is(@"2012-12-25", @"2012-12-25T00:00:00")')).must_equal false
        _(evaluate('is(duration("P1Y"), duration("P365D"))')).must_equal false
        _(evaluate('is({a: 1}, {a: "1"})')).must_equal false
      end

      it "should support the examples of the specification" do
        _(evaluate('is(time("23:00:50z"), time("23:00:50"))')).must_equal false
        _(evaluate('is(time("23:00:50z"), time("23:00:50+00:00"))')).must_equal true
      end

      it "should compare the offset and zone of times and date-times" do
        _(evaluate('time("10:00:00+01:00") = time("10:00:00+01:00")')).must_equal true
        _(evaluate('is(time("10:00:00+01:00"), time("09:00:00Z"))')).must_equal false
        _(evaluate('date and time("2018-12-08T10:30:00+01:00") = date and time("2018-12-08T09:30:00Z")')).must_equal true
        _(evaluate('is(date and time("2018-12-08T10:30:00+01:00"), date and time("2018-12-08T09:30:00Z"))')).must_equal false
        _(evaluate('is(date and time("2018-12-08T10:30:00+01:00"), date and time("2018-12-08T10:30:00@Europe/Paris"))')).must_equal false
        _(evaluate('is(date and time("2018-12-08T10:30:00@Europe/Paris"), date and time("2018-12-08T10:30:00@Europe/Paris"))')).must_equal true
      end
    end

    describe "list replace()" do
      it "should replace the item at a position" do
        _(evaluate("list replace([2, 4, 7, 8], 3, 6)")).must_equal [2, 4, 6, 8]
        _(evaluate("list replace([2, 4, 7, 8], -1, 6)")).must_equal [2, 4, 7, 6]
        _(evaluate("list replace([1, 2], 1, null)")).must_equal [nil, 2]
        _(evaluate("list replace(list: [1, 2], position: 1, newItem: 0)")).must_equal [0, 2]
      end

      it "should replace the items that match" do
        _(evaluate("list replace([2, 4, 7, 8], function(item, newItem) item < newItem, 5)")).must_equal [5, 5, 7, 8]
        _(evaluate("list replace(list: [2, 4, 7, 8], match: function(item, newItem) item > newItem, newItem: 5)")).must_equal [2, 4, 5, 5]
      end

      it "should not modify the list" do
        list = [1, 2, 3]
        _(evaluate("list replace(list, 1, 0)", list: list)).must_equal [0, 2, 3]
        _(list).must_equal [1, 2, 3]
      end

      it "should return null for invalid arguments" do
        _(evaluate("list replace([2, 4, 7, 8], 5, 6)")).must_be_nil
        _(evaluate("list replace([2, 4, 7, 8], 0, 6)")).must_be_nil
        _(evaluate("list replace([1, 2], 1)")).must_be_nil
        _(evaluate("list replace(null, 1, 0)")).must_be_nil
        _(evaluate('list replace([1, 2], function(item, newItem) "x", 0)')).must_be_nil
      end
    end

    describe "range()" do
      it "should create a range from a range literal" do
        _(evaluate('range("[1..10]")')).must_equal Range.build(1, 10, true, true)
        _(evaluate('range("(1..10]")')).must_equal Range.build(1, 10, false, true)
        _(evaluate('range("]1..10[")')).must_equal Range.build(1, 10, false, false)
        _(evaluate('range("< 5")')).must_equal Range.build(nil, 5, false, false)
        _(evaluate('range(">= 5")')).must_equal Range.build(5, nil, true, false)
        _(evaluate('range("[\"a\"..\"z\"]")')).must_equal Range.build("a", "z", true, true)
        _(evaluate('range("[date(\"2020-01-01\")..@\"2020-12-31\"]")')).must_equal Range.build(Date.new(2020, 1, 1), Date.new(2020, 12, 31), true, true)
      end

      it "should be usable as a range value" do
        _(evaluate('5 in range("[1..10]")')).must_equal true
        _(evaluate('11 in range("[1..10]")')).must_equal false
        _(evaluate('includes(range("[1..10]"), 3)')).must_equal true
        _(evaluate('string(range("[1..10)"))')).must_equal "[1..10)"
      end

      it "should return null for invalid range literals" do
        _(evaluate('range("1..10")')).must_be_nil
        _(evaluate('range("[1..x]")')).must_be_nil
        _(evaluate('range("[1..\"z\"]")')).must_be_nil
        _(evaluate("range(5)")).must_be_nil
        _(evaluate("range(null)")).must_be_nil
      end
    end

    describe "range properties" do
      it "should access the start and end of a range" do
        _(evaluate('range("(1..10]").start')).must_equal 1
        _(evaluate('range("(1..10]").end')).must_equal 10
        _(evaluate('range("(1..10]").start included')).must_equal false
        _(evaluate('range("(1..10]").end included')).must_equal true
        _(evaluate('range("< 10").start')).must_be_nil
        _(evaluate("r.end included", r: Range.build(1, 5, true, false))).must_equal false
      end

      it "should still access context entries named like range properties" do
        _(evaluate("x.start", x: { start: 3 })).must_equal 3
        _(evaluate('{start included: 1}.`start included`')).must_equal 1
      end
    end

    describe "Camunda extensions" do
      it "should be enabled by default" do
        _(evaluate('is blank("")')).must_equal true
        _(evaluate("uuid()")).must_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      end

      it "should be disabled with config.camunda_extensions = false" do
        expression = FEEL.compile('is blank("")')
        FEEL.config.camunda_extensions = false
        Builtins::CAMUNDA_EXTENSIONS.each do |name|
          _(LiteralExpression.builtin_functions).wont_include name
        end
        _(expression.evaluate).must_be_nil
        _(evaluate('string length("ab")')).must_equal 2
        _(evaluate('is(1, 1)')).must_equal true

        FEEL.config.strict = true
        _ { evaluate("uuid()") }.must_raise EvaluationError
      end

      it "should list only existing functions" do
        _(Builtins::CAMUNDA_EXTENSIONS - LiteralExpression.all_builtin_functions.keys).must_be_empty
      end
    end
  end
end
