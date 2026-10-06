# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterExpressionTest
module FEEL
  describe "syntax" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe :comments do
      it "should support end of line comments" do
        _(evaluate("[1,2,3][1] // the first item")).must_equal 1
      end

      it "should support trailing comments" do
        _(evaluate("[1,2,3][1] /* the first item */")).must_equal 1
      end

      it "should support single line comments" do
        _(evaluate(<<~FEEL)).must_equal 1
          /* the first item */
          [1,2,3][1]
        FEEL
      end

      it "should support block comments" do
        _(evaluate(<<~FEEL)).must_equal 1
          /*
           * the first item
           */
          [1,2,3][1]
        FEEL
      end

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
      it "should not accept a reserved word as a variable name" do
        %w[null true false function in return then else satisfies and or].each do |keyword|
          next if %w[null true false].include?(keyword)

          _(LiteralExpression.new(text: keyword).valid?).must_equal false, "expected '#{keyword}' to be invalid"
        end
        _(LiteralExpression.new(text: "{ null: 1 }.null").valid?).must_equal false
        _(LiteralExpression.new(text: "{ true: 1 }.true").valid?).must_equal false
      end

      %w[something everything often orY andX trueX falseY nullOrString functionX instances forDev
         ifImportant thenX elseY betweenXandY notThis inside durationX dateX timeX inX in1].each do |name|
        it "should accept a variable name containing a keyword (#{name})" do
          _(evaluate("#{name} = true", name.to_sym => true)).must_equal true
        end
      end

      it "should support escaped names" do
        _(evaluate("`x`", x: "foo")).must_equal "foo"
        _(evaluate("`a b`", "a b": "foo")).must_equal "foo"
        _(evaluate("`a-b`", "a-b": 3)).must_equal 3
      end

      it "should support names with whitespaces in context keys" do
        _(evaluate("{first name: \"John\"}.`first name`")).must_equal "John"
      end
    end

    describe :whitespace do
      chars = ["\u0009", " ", "\u0085", " ", " ", "᠎", " ", " ", " ",
               " ", " ", " ", " ", " ", " ", " ", " ", "​",
               " ", " ", " ", " ", "　", "﻿", "\u000A", "\u000B", "\u000C",
               "\u000D"]

      it "should be ignored around literals and operators" do
        chars.each do |ws|
          _(FEEL::Parser.parse("#{ws}1+2#{ws}").eval).must_equal 3
          _(FEEL::Parser.parse("1#{ws}+#{ws}2").eval).must_equal 3
          _(FEEL::Parser.parse("1#{ws}<#{ws}2").eval).must_equal true
          _(FEEL::Parser.parse("{#{ws}x#{ws}:#{ws}1#{ws}}").eval).must_equal({ "x" => 1 })
        end
      end

      it "should be ignored inside for and quantified expressions" do
        chars.each do |ws|
          _(FEEL::Parser.parse("for#{ws}x#{ws}in#{ws}[1]#{ws}return#{ws}x").eval).must_equal [1]
          _(FEEL::Parser.parse("some#{ws}x#{ws}in#{ws}[1]#{ws}satisfies#{ws}odd(x)").eval(LiteralExpression.builtin_functions)).must_equal true
          _(FEEL::Parser.parse("every#{ws}x#{ws}in#{ws}[1]#{ws}satisfies#{ws}odd(x)").eval(LiteralExpression.builtin_functions)).must_equal true
        end
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

    describe :simple_positive_unary_test do
      it "should be evaluated against the input value" do
        _(evaluate("< 3", "?": 2)).must_equal true
        _(evaluate("(2 .. 4)", "?": 5)).must_equal false
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
    end
  end
end
