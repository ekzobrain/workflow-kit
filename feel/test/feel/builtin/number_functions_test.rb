# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinNumberFunctionTest
module FEEL
  describe "built-in number functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A decimal() function" do
      it "should return number with a given scale" do
        _(evaluate(" decimal((1/3), 2) ")).must_equal 0.33
        _(evaluate(" decimal(1.5, 0) ")).must_equal 2
        _(evaluate(" decimal(2.5, 0) ")).must_equal 2
      end

      it "should use the given rounding mode" do
        # see https://docs.oracle.com/javase/7/docs/api/java/math/RoundingMode.html

        _(evaluate(' decimal(5.5, 0, "UP") ')).must_equal 6
        _(evaluate(' decimal(5.5, 0, "DOWN") ')).must_equal 5
        _(evaluate(' decimal(5.5, 0, "CEILING") ')).must_equal 6
        _(evaluate(' decimal(5.5, 0, "FLOOR") ')).must_equal 5
        _(evaluate(' decimal(5.5, 0, "HALF_UP") ')).must_equal 6
        _(evaluate(' decimal(5.5, 0, "HALF_DOWN") ')).must_equal 5
        _(evaluate(' decimal(5.5, 0, "HALF_EVEN") ')).must_equal 6
        _(evaluate(' decimal(5.5, 0, "UNNECESSARY") ')).must_be_nil

        _(evaluate(' decimal(2.5, 0, "UP") ')).must_equal 3
        _(evaluate(' decimal(2.5, 0, "DOWN") ')).must_equal 2
        _(evaluate(' decimal(2.5, 0, "CEILING") ')).must_equal 3
        _(evaluate(' decimal(2.5, 0, "FLOOR") ')).must_equal 2
        _(evaluate(' decimal(2.5, 0, "HALF_UP") ')).must_equal 3
        _(evaluate(' decimal(2.5, 0, "HALF_DOWN") ')).must_equal 2
        _(evaluate(' decimal(2.5, 0, "HALF_EVEN") ')).must_equal 2
        _(evaluate(' decimal(2.5, 0, "UNNECESSARY") ')).must_be_nil

        _(evaluate(' decimal(1.6, 0, "UP") ')).must_equal 2
        _(evaluate(' decimal(1.6, 0, "DOWN") ')).must_equal 1
        _(evaluate(' decimal(1.6, 0, "CEILING") ')).must_equal 2
        _(evaluate(' decimal(1.6, 0, "FLOOR") ')).must_equal 1
        _(evaluate(' decimal(1.6, 0, "HALF_UP") ')).must_equal 2
        _(evaluate(' decimal(1.6, 0, "HALF_DOWN") ')).must_equal 2
        _(evaluate(' decimal(1.6, 0, "HALF_EVEN") ')).must_equal 2
        _(evaluate(' decimal(1.6, 0, "UNNECESSARY") ')).must_be_nil

        _(evaluate(' decimal(1.1, 0, "UP") ')).must_equal 2
        _(evaluate(' decimal(1.1, 0, "DOWN") ')).must_equal 1
        _(evaluate(' decimal(1.1, 0, "CEILING") ')).must_equal 2
        _(evaluate(' decimal(1.1, 0, "FLOOR") ')).must_equal 1
        _(evaluate(' decimal(1.1, 0, "HALF_UP") ')).must_equal 1
        _(evaluate(' decimal(1.1, 0, "HALF_DOWN") ')).must_equal 1
        _(evaluate(' decimal(1.1, 0, "HALF_EVEN") ')).must_equal 1
        _(evaluate(' decimal(1.1, 0, "UNNECESSARY") ')).must_be_nil

        _(evaluate(' decimal(1.0, 0, "UP") ')).must_equal 1
        _(evaluate(' decimal(1.0, 0, "DOWN") ')).must_equal 1
        _(evaluate(' decimal(1.0, 0, "CEILING") ')).must_equal 1
        _(evaluate(' decimal(1.0, 0, "FLOOR") ')).must_equal 1
        _(evaluate(' decimal(1.0, 0, "HALF_UP") ')).must_equal 1
        _(evaluate(' decimal(1.0, 0, "HALF_DOWN") ')).must_equal 1
        _(evaluate(' decimal(1.0, 0, "HALF_EVEN") ')).must_equal 1
        _(evaluate(' decimal(1.0, 0, "UNNECESSARY") ')).must_equal 1

        _(evaluate(' decimal(-1.0, 0, "UP") ')).must_equal(-1)
        _(evaluate(' decimal(-1.0, 0, "DOWN") ')).must_equal(-1)
        _(evaluate(' decimal(-1.0, 0, "CEILING") ')).must_equal(-1)
        _(evaluate(' decimal(-1.0, 0, "FLOOR") ')).must_equal(-1)
        _(evaluate(' decimal(-1.0, 0, "HALF_UP") ')).must_equal(-1)
        _(evaluate(' decimal(-1.0, 0, "HALF_DOWN") ')).must_equal(-1)
        _(evaluate(' decimal(-1.0, 0, "HALF_EVEN") ')).must_equal(-1)
        _(evaluate(' decimal(-1.0, 0, "UNNECESSARY") ')).must_equal(-1)

        _(evaluate(' decimal(-1.1, 0, "UP") ')).must_equal(-2)
        _(evaluate(' decimal(-1.1, 0, "DOWN") ')).must_equal(-1)
        _(evaluate(' decimal(-1.1, 0, "CEILING") ')).must_equal(-1)
        _(evaluate(' decimal(-1.1, 0, "FLOOR") ')).must_equal(-2)
        _(evaluate(' decimal(-1.1, 0, "HALF_UP") ')).must_equal(-1)
        _(evaluate(' decimal(-1.1, 0, "HALF_DOWN") ')).must_equal(-1)
        _(evaluate(' decimal(-1.1, 0, "HALF_EVEN") ')).must_equal(-1)
        _(evaluate(' decimal(-1.1, 0, "UNNECESSARY") ')).must_be_nil

        _(evaluate(' decimal(-1.6, 0, "UP") ')).must_equal(-2)
        _(evaluate(' decimal(-1.6, 0, "DOWN") ')).must_equal(-1)
        _(evaluate(' decimal(-1.6, 0, "CEILING") ')).must_equal(-1)
        _(evaluate(' decimal(-1.6, 0, "FLOOR") ')).must_equal(-2)
        _(evaluate(' decimal(-1.6, 0, "HALF_UP") ')).must_equal(-2)
        _(evaluate(' decimal(-1.6, 0, "HALF_DOWN") ')).must_equal(-2)
        _(evaluate(' decimal(-1.6, 0, "HALF_EVEN") ')).must_equal(-2)
        _(evaluate(' decimal(-1.6, 0, "UNNECESSARY") ')).must_be_nil

        _(evaluate(' decimal(-2.5, 0, "UP") ')).must_equal(-3)
        _(evaluate(' decimal(-2.5, 0, "DOWN") ')).must_equal(-2)
        _(evaluate(' decimal(-2.5, 0, "CEILING") ')).must_equal(-2)
        _(evaluate(' decimal(-2.5, 0, "FLOOR") ')).must_equal(-3)
        _(evaluate(' decimal(-2.5, 0, "HALF_UP") ')).must_equal(-3)
        _(evaluate(' decimal(-2.5, 0, "HALF_DOWN") ')).must_equal(-2)
        _(evaluate(' decimal(-2.5, 0, "HALF_EVEN") ')).must_equal(-2)
        _(evaluate(' decimal(-2.5, 0, "UNNECESSARY") ')).must_be_nil

        _(evaluate(' decimal(-5.5, 0, "UP") ')).must_equal(-6)
        _(evaluate(' decimal(-5.5, 0, "DOWN") ')).must_equal(-5)
        _(evaluate(' decimal(-5.5, 0, "CEILING") ')).must_equal(-5)
        _(evaluate(' decimal(-5.5, 0, "FLOOR") ')).must_equal(-6)
        _(evaluate(' decimal(-5.5, 0, "HALF_UP") ')).must_equal(-6)
        _(evaluate(' decimal(-5.5, 0, "HALF_DOWN") ')).must_equal(-5)
        _(evaluate(' decimal(-5.5, 0, "HALF_EVEN") ')).must_equal(-6)
        _(evaluate(' decimal(-5.5, 0, "UNNECESSARY") ')).must_be_nil
      end

      it "should use the given rounding mode (case-insensitive)" do
        _(evaluate(' decimal(1.5, 0, "CEILING") ')).must_equal 2
        _(evaluate(' decimal(1.5, 0, "ceiling") ')).must_equal 2
        _(evaluate(' decimal(1.5, 0, "CeiLing") ')).must_equal 2
      end

      it "should return null if the rounding mode is not valid" do
        _(evaluate(' decimal(1.5, 0, "unknown") ')).must_be_nil
      end
    end

    describe "A floor() function" do
      it "should return greatest integer <= _" do
        _(evaluate(" floor(1.5) ")).must_equal 1
        _(evaluate(" floor(-1.5) ")).must_equal(-2)
        _(evaluate(" floor(-1.56, 1) ")).must_equal(-1.6)
      end
    end

    describe "A ceiling() function" do
      it "should return smallest integer >= _" do
        _(evaluate(" ceiling(1.5) ")).must_equal 2
        _(evaluate(" ceiling(-1.5) ")).must_equal(-1)
        _(evaluate(" ceiling(-1.56, 1) ")).must_equal(-1.5)
      end
    end

    describe "A abs() function" do
      it "should return absolute value" do
        _(evaluate(" abs(10) ")).must_equal 10
        _(evaluate(" abs(-10) ")).must_equal 10
      end

      it "should be invoked with named parameter number" do
        _(evaluate(" abs(number: 1) ")).must_equal 1
        _(evaluate(" abs(number: -1) ")).must_equal 1
      end

      it "should be invoked with named parameter n" do
        _(evaluate(" abs(n: 1) ")).must_equal 1
        _(evaluate(" abs(n: -1) ")).must_equal 1
      end
    end

    describe "A modulo() function" do
      it "should return the remainder of the division of dividend by divisor" do
        _(evaluate(" modulo(12, 5) ")).must_equal 2
      end

      it "should return the negative reminder of the division of dividend by divisor" do
        _(evaluate(" modulo(12, -5) ")).must_equal(-3)
        _(evaluate(" modulo(-12, -5) ")).must_equal(-2)
        _(evaluate(" modulo(10.1, -4.5) ")).must_equal(-3.4)
        _(evaluate(" modulo(-10.1, -4.5) ")).must_equal(-1.1)
      end

      it "should return the positive reminder of the division of dividend by divisor" do
        _(evaluate(" modulo(-12, 5) ")).must_equal 3
        _(evaluate(" modulo(-10.1, 4.5) ")).must_equal 3.4
      end
    end

    describe "A sqrt() function" do
      it "should return square root" do
        _(evaluate(" sqrt(16) ")).must_equal 4
        _(evaluate(" sqrt(-1) ")).must_be_nil
      end
    end

    describe "A log() function" do
      it "should return natural logarithm" do
        _(evaluate(" log( 10 ) ")).must_equal 2.302585092994046
      end
    end

    describe "A exp() function" do
      it "should return Euler’s number e raised to the power of number" do
        _(evaluate(" exp( 5 ) ")).must_equal 148.4131591025766
      end
    end

    describe "A odd() function" do
      it "should return true if number is odd" do
        _(evaluate(" odd(5) ")).must_equal true
        _(evaluate(" odd(2) ")).must_equal false
      end

      it "should return true if negative number is odd" do
        _(evaluate(" odd(-5)")).must_equal true
        _(evaluate(" odd(-2)")).must_equal false
      end
    end

    describe "A even() function" do
      it "should return true if number is even" do
        _(evaluate(" even(5) ")).must_equal false
        _(evaluate(" even(2) ")).must_equal true
      end
    end

    describe "A round up() function" do
      it "should return number with a given scale" do
        _(evaluate(" round up(5.5, 0) ")).must_equal 6
        _(evaluate(" round up(-5.5, 0) ")).must_equal(-6)
        _(evaluate(" round up(1.121, 2) ")).must_equal 1.13
        _(evaluate(" round up(-1.126, 2) ")).must_equal(-1.13)
      end
    end

    describe "A round down() function" do
      it "should return number with a given scale" do
        _(evaluate(" round down(5.5, 0) ")).must_equal 5
        _(evaluate(" round down(-5.5, 0) ")).must_equal(-5)
        _(evaluate(" round down(1.121, 2) ")).must_equal 1.12
        _(evaluate(" round down(-1.126, 2) ")).must_equal(-1.12)
      end
    end

    describe "A round half up() function" do
      it "should return number with a given scale" do
        _(evaluate(" round half up(5.5, 0) ")).must_equal 6
        _(evaluate(" round half up(-5.5, 0) ")).must_equal(-6)
        _(evaluate(" round half up(1.121, 2) ")).must_equal 1.12
        _(evaluate(" round half up(-1.126, 2) ")).must_equal(-1.13)
      end
    end

    describe "A round half down() function" do
      it "should return number with a given scale" do
        _(evaluate(" round half down(5.5, 0) ")).must_equal 5
        _(evaluate(" round half down(-5.5, 0) ")).must_equal(-5)
        _(evaluate(" round half down(1.121, 2) ")).must_equal 1.12
        _(evaluate(" round half down(-1.126, 2) ")).must_equal(-1.13)
      end
    end

    describe "A random number() function" do
      it "should return a number" do
        _(evaluate(" random number() ")).must_be_kind_of Numeric
      end

      it "should return a number between 0.0 and 1.0 " do
        result = evaluate(" random number() ")
        _(result).must_be :>=, 0
        _(result).must_be :<=, 1
      end
    end
  end
end
