# frozen_string_literal: true

require "test_helper"

# Semantics of the DMN specification (checked by the DMN TCK, see
# test/tck) that feel-scala doesn't implement.
module FEEL
  describe "DMN TCK semantics" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "instance of structured types" do
      it "should check list and range types" do
        _(evaluate("[1, 2] instance of list<number>")).must_equal true
        _(evaluate("[1, null] instance of list<number>")).must_equal true
        _(evaluate('[1, "2"] instance of list<number>')).must_equal false
        _(evaluate("[] instance of list<string>")).must_equal true
        _(evaluate("[[1]] instance of list<list<number>>")).must_equal true
        _(evaluate("[1..3] instance of range<number>")).must_equal true
        _(evaluate("[1..3] instance of range<string>")).must_equal false
        _(evaluate('[@"2020-01-01"..@"2020-12-31"] instance of range<date>')).must_equal true
      end

      it "should check context types" do
        _(evaluate('{a: 1, b: "x"} instance of context<a: number>')).must_equal true
        _(evaluate('{a: 1, b: "x"} instance of context<a: number, b: string>')).must_equal true
        _(evaluate("{a: null} instance of context<a: string>")).must_equal true
        _(evaluate('{a: "1"} instance of context<a: number>')).must_equal false
        _(evaluate("{b: 1} instance of context<a: number>")).must_equal false
        _(evaluate("1 instance of context<a: number>")).must_equal false
      end

      it "should check function types" do
        _(evaluate("(function(x) x) instance of function<number> -> Any")).must_equal true
        _(evaluate("(function(x, y) x) instance of function<number> -> Any")).must_equal false
        _(evaluate("1 instance of function<number> -> Any")).must_equal false
      end
    end

    describe "for over ranges" do
      it "should iterate over dates" do
        _(evaluate('for i in @"1980-01-01"..@"1980-01-03" return i')).must_equal [Date.new(1980, 1, 1), Date.new(1980, 1, 2), Date.new(1980, 1, 3)]
        _(evaluate('for i in @"1980-01-03"..@"1980-01-01" return i')).must_equal [Date.new(1980, 1, 3), Date.new(1980, 1, 2), Date.new(1980, 1, 1)]
        _(evaluate('for i in [@"1980-01-01"..@"1980-01-03") return i')).must_equal [Date.new(1980, 1, 1), Date.new(1980, 1, 2)]
      end

      it "should be null for a descending range literal" do
        _(evaluate("for i in [1..3] return i")).must_equal [1, 2, 3]
        _(evaluate("for i in 3..1 return i")).must_equal [3, 2, 1]
        _(evaluate("for i in [3..1] return i")).must_be_nil
      end
    end

    describe "matches()" do
      it "should reject invalid flags" do
        _(evaluate('matches("abc", "b", "p")')).must_be_nil
        _(evaluate('matches("abc", "b", " ")')).must_be_nil
        _(evaluate('matches("abc", "b", [])')).must_be_nil
        _(evaluate('matches("abc", "B", "i")')).must_equal true
      end

      it "should remove whitespace with the x flag" do
        _(evaluate('matches("hello world", "hello\\ sworld", "x")')).must_equal true
        _(evaluate('matches("hello world", "\\p{ IsBasicLatin}+", "x")')).must_equal true
        _(evaluate('matches("a b", "a[ ]b", "x")')).must_equal true
      end

      it "should match a literal pattern with the q flag" do
        _(evaluate('matches("a.b", ".", "q")')).must_equal true
        _(evaluate('matches("abc", ".", "q")')).must_equal false
      end

      it "should support character class subtraction" do
        _(evaluate('matches("B", "^[A-Z-[OI]]$")')).must_equal true
        _(evaluate('matches("O", "^[A-Z-[OI]]$", "i")')).must_equal false
      end

      it "should not match line breaks with a dot" do
        _(evaluate('matches("a\\u000Db", "a.b")')).must_equal false
        _(evaluate('matches("a\\nb", "a.b")')).must_equal false
        _(evaluate('matches("a\\nb", "a.b", "s")')).must_equal true
      end

      it "should reject invalid back-references" do
        _(evaluate('matches("abcd", "(asd)[\\1]")')).must_be_nil
        _(evaluate('matches("abcd", "1[asd\\0]")')).must_be_nil
        _(evaluate('matches("abab", "(ab)\\1")')).must_equal true
      end
    end

    describe "temporal values" do
      it "should accept 24:00:00 as the end of a day" do
        _(evaluate('@"2021-01-01T24:00:00"')).must_equal LocalDateTime.new(2021, 1, 2, 0, 0, 0)
        _(evaluate('@"2021-01-01T24:00:00" + @"PT1S"')).must_equal LocalDateTime.new(2021, 1, 2, 0, 0, 1)
        _(evaluate('date and time("2017-12-31T24:00:01")')).must_be_nil
      end

      it "should reject offsets beyond 18 hours" do
        _(evaluate('time("13:20:00+19:00")')).must_be_nil
        _(evaluate('date and time("2017-12-31T13:20:00-19:00")')).must_be_nil
        _(evaluate('time("13:20:00+18:00")')).wont_be_nil
      end

      it "should subtract a date from a date and time with an offset or zone" do
        _(evaluate('@"2021-01-02T10:10:10+01:00" - @"2021-01-01"')).must_equal evaluate('@"P1DT9H10M10S"')
        _(evaluate('@"2021-01-02" - @"2021-01-01T10:10:10+11:00"')).must_equal evaluate('@"P1DT49M50S"')
        _(evaluate('@"2021-01-02T10:10:10" - @"2021-01-01"')).must_be_nil
      end

      it "should not subtract local and zoned date and times" do
        _(evaluate('@"2021-01-02T10:10:10+02:00" - @"2021-01-01T10:10:10"')).must_be_nil
        _(evaluate('@"2021-01-02T10:10:10" - @"2021-01-01T10:10:10@Europe/Paris"')).must_be_nil
      end

      it "should validate the fields of date()" do
        _(evaluate("date(2017, -8, 2)")).must_be_nil
        _(evaluate("date(2017, 8, -2)")).must_be_nil
        _(evaluate("date(-1000999999, 12, 1)")).must_be_nil
      end

      it "should accept the named parameters of all signatures" do
        _(evaluate("date(year: 2017, month: 8, day: 30)")).must_equal Date.new(2017, 8, 30)
        _(evaluate('date(from: "2017-08-30")')).must_equal Date.new(2017, 8, 30)
        _(evaluate('time(hour: 11, minute: 59, second: 0, offset: duration("-PT2H"))')).must_equal evaluate('time("11:59:00-02:00")')
        _(evaluate('date and time(date: date("2017-01-01"), time: time("23:59:01"))')).must_equal LocalDateTime.new(2017, 1, 1, 23, 59, 1)
      end

      it "should be null for an explicit null time" do
        _(evaluate('date and time(date("2017-08-10"), null)')).must_be_nil
        _(evaluate('date and time("2017-08-10T10:20:00")')).must_equal LocalDateTime.new(2017, 8, 10, 10, 20, 0)
      end
    end
  end
end
