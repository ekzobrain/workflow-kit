# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: ValComparatorTest
#
# The Scala test exercises the internal ValComparator class directly. Only the
# parts that are expressible as FEEL expressions are ported: `x = y` with
# FEEL literals for the compared values.
module FEEL
  describe "value comparator" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    def assert_equals(x, y)
      _(evaluate("#{x} = #{y}")).must_equal true, "expected #{x} = #{y}"
    end

    def assert_not_equals(x, y)
      _(evaluate("#{x} = #{y}")).must_equal false, "expected #{x} != #{y}"
    end

    describe "ValComparator.compare" do
      it "should compare null values" do
        _(evaluate("null = null")).must_equal true
        _(evaluate("null = 1")).must_equal false
        _(evaluate("1 = null")).must_equal false

        # Not applicable: ValError/ValFatalError are internal Scala values, not FEEL values
      end

      it "should compare equal simple FEEL values" do
        [
          ["1", "1"],
          ["true", "true"],
          ['"a"', '"a"'],
          ['@"2017-04-02"', '@"2017-04-02"'],
          ['@"12:04:30"', '@"12:04:30"'],
          ['@"12:04:30+01:00"', '@"12:04:30+01:00"'],
          ['@"2017-04-02T12:04:30"', '@"2017-04-02T12:04:30"'],
          ['@"2017-04-02T12:04:30+01:00"', '@"2017-04-02T12:04:30+01:00"'],
          ['@"P2Y4M"', '@"P2Y4M"'],
          ['@"PT4H22M"', '@"PT4H22M"'],
        ].each { |x, y| assert_equals(x, y) }
      end

      it "should compare different simple FEEL values" do
        [
          ["1", "2"],
          ["true", "false"],
          ['"a"', '"b"'],
          ['@"2017-04-02"', '@"2017-04-03"'],
          ['@"12:04:30"', '@"12:04:31"'],
          ['@"12:04:30+01:00"', '@"12:04:30+02:00"'],
          ['@"2017-04-02T12:04:30"', '@"2017-04-02T12:04:31"'],
          ['@"2017-04-02T12:04:30+01:00"', '@"2017-04-02T12:04:30+02:00"'],
          ['@"P2Y4M"', '@"P2Y5M"'],
          ['@"PT4H22M"', '@"PT4H23M"'],
        ].each { |x, y| assert_not_equals(x, y) }
      end

      it "should compare equal lists (including nested lists)" do
        assert_equals('[1, "a"]', '[1, "a"]')
        assert_equals('[[1], ["x"]]', '[[1], ["x"]]')
      end

      it "should compare different lists" do
        assert_not_equals('[1, "a"]', '[1, "b"]')
        assert_not_equals('[1, "a"]', '["a", 1]')
        assert_not_equals('[1, "a"]', '[1, "a", "x"]')
        assert_not_equals('[[1], ["x"]]', '[[2], ["x"]]')
      end

      it "should compare contexts using ValueMapper.toVal" do
        x = { "a" => 1, "b" => "x" }
        y = { "a" => 1, "b" => "x" }
        z = { "a" => 1, "b" => "y" }

        _(evaluate("x = y", x: x, y: y)).must_equal true
        _(evaluate("x = z", x: x, z: z)).must_equal false

        nested_x = { "a" => { "x" => 1 } }
        nested_y = { "a" => { "x" => 1 } }
        nested_z = { "a" => { "x" => 2 } }

        _(evaluate("x = y", x: nested_x, y: nested_y)).must_equal true
        _(evaluate("x = z", x: nested_x, z: nested_z)).must_equal false

        different_keys = { "a" => 1 }
        _(evaluate("x = y", x: x, y: different_keys)).must_equal false
      end

      it "should return an error for values of different types" do
        _(evaluate("1 = true")).must_be_nil
        _(evaluate('1 = "a"')).must_be_nil
        _(evaluate('1 = @"P1D"')).must_be_nil
      end

      it "should return an error for unsupported Val types" do
        _(evaluate("x = y", x: evaluate("function(a) 1"), y: evaluate("function(a) 1"))).must_be_nil
        _(evaluate("(function(a) 1) = (function(a) 1)")).must_be_nil

        # Not applicable: ranges as values are owned by the range area, see range tests
        # Not applicable: ValError/ValFatalError are internal Scala values, not FEEL values
      end
    end

    describe "ValComparator.hashCode" do
      # Not applicable: hash codes of the internal Scala values (compute hash codes for null-like values)

      it "should compute hash codes for supported Val types" do
        # expressed as equality of the values (hash codes are internal)
        [
          ["1", "1"],
          ["true", "true"],
          ['"a"', '"a"'],
          ['@"2017-04-02"', '@"2017-04-02"'],
          ['@"12:04:30"', '@"12:04:30"'],
          ['@"12:04:30+01:00"', '@"12:04:30+01:00"'],
          ['@"2017-04-02T12:04:30"', '@"2017-04-02T12:04:30"'],
          ['@"2017-04-02T12:04:30+01:00"', '@"2017-04-02T12:04:30+01:00"'],
          ['@"P2Y4M"', '@"P2Y4M"'],
          ['@"PT4H22M"', '@"PT4H22M"'],
          ['[1, "a"]', '[1, "a"]'],
          ['{a: 1, b: "x"}', '{a: 1, b: "x"}'],
        ].each { |x, y| assert_equals(x, y) }
      end

      it "should compute the same hash code for contexts with key order differences" do
        # expressed as equality of contexts with a different key order
        ctx1 = { "a" => 1, "b" => "x", "c" => [1, 2, 3], "d" => { "nested" => { "x" => 1, "y" => "z" } }, "e" => true }
        ctx2 = { "e" => true, "d" => { "nested" => { "y" => "z", "x" => 1 } }, "c" => [1, 2, 3], "b" => "x", "a" => 1 }

        _(evaluate("x = y", x: ctx1, y: ctx2)).must_equal true
      end

      # Not applicable: hash codes of the internal Scala values (compute hash codes for unsupported Val types)
    end
  end
end
