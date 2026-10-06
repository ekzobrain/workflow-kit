# frozen_string_literal: true

require "test_helper"

module FEEL
  describe Parser do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    it "should be a Treetop compiled parser" do
      _(Parser.ancestors).must_include Treetop::Runtime::CompiledParser
    end

    it "should parse and evaluate expressions" do
      _(Parser.parse("1 + 1").eval).must_equal 2
    end

    it "should parse unary tests" do
      _(Parser.parse_test("< 10")).wont_be_nil
    end

    describe :exponentiation do
      it "should be left-associative" do
        _(evaluate("2**2**3")).must_equal 64
        _(evaluate("(2**2)**3")).must_equal 64
        _(evaluate("2**(2**3)")).must_equal 256
      end

      it "should accept a negative exponent" do
        _(evaluate("2**-1")).must_equal 0.5
      end
    end

    describe "and/or function names" do
      it "should invoke functions named and/or" do
        all = ->(*args) { args.flatten.all? }
        any = ->(*args) { args.flatten.any? }
        _(evaluate("and([true, false])", and: all)).must_equal false
        _(evaluate("or(true, false)", or: any)).must_equal true
      end

      it "should still parse a conjunction/disjunction with parentheses" do
        _(evaluate("a and (b)", a: true, b: false)).must_equal false
        _(evaluate("a or (b)", a: false, b: true)).must_equal true
        _(evaluate("true and(false)")).must_equal false
      end
    end

    describe :string_escapes do
      it "should translate known escape sequences" do
        _(evaluate('"a\\nb"')).must_equal "a\nb"
        _(evaluate('"a\\tb"')).must_equal "a\tb"
        _(evaluate('"a\\rb"')).must_equal "a\rb"
        _(evaluate('"a\\bb"')).must_equal "a\bb"
        _(evaluate('"a\\fb"')).must_equal "a\fb"
        _(evaluate('"a\\"b"')).must_equal 'a"b'
        _(evaluate("'a\\'b'")).must_equal "a'b"
        _(evaluate('"a\\\\b"')).must_equal "a\\b"
        _(evaluate('"\\u0041"')).must_equal "A"
      end

      it "should keep other escape sequences as they are" do
        _(evaluate('"\\s"')).must_equal "\\s"
        _(evaluate('"\\d+"')).must_equal "\\d+"
        _(evaluate('"\\U101EF"')).must_equal "\\U101EF"
      end
    end

    describe :backtick_names do
      it "should normalize whitespaces" do
        _(evaluate("{foo   bar:2}.`foo   bar`")).must_equal 2
      end
    end
  end
end
