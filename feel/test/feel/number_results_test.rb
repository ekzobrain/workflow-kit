# frozen_string_literal: true

require "test_helper"

# Numbers are computed exactly (BigDecimal, 34 digits) and returned as
# Integer, Float (if it has exactly the same value) or BigDecimal.
module FEEL
  describe "Number results" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    it "should return integral numbers as Integer" do
      _(evaluate("10 / 2")).must_be_instance_of Integer
      _(evaluate("1.5 * 2")).must_equal 3
    end

    it "should return numbers that a Float represents exactly as Float" do
      _(evaluate("0.1 + 0.2")).must_equal 0.3
      _(evaluate("0.1 + 0.2")).must_be_instance_of Float
      _(evaluate("1 / 4")).must_equal 0.25
      _(evaluate("sum([0.1, 0.2])")).must_equal 0.3
    end

    it "should return the other numbers as BigDecimal" do
      _(evaluate("1 / 3")).must_equal BigDecimal("0.3333333333333333333333333333333333")
      _(evaluate("12345678901234567.89 + 0")).must_equal BigDecimal("12345678901234567.89")
      _(evaluate('number("0.12345678901234567890")')).must_equal BigDecimal("0.1234567890123456789")
      _(evaluate('duration("PT1H") / duration("PT3H")')).must_be_instance_of BigDecimal
    end

    it "should keep the precision of results passed as variables" do
      third = evaluate("1 / 3")
      _(evaluate("x * 3", x: third)).must_equal BigDecimal("0.9999999999999999999999999999999999")
    end

    it "should write all the digits in JSON" do
      _(evaluate("to json([0.5, 1 / 3])")).must_equal "[0.5,0.3333333333333333333333333333333333]"
      _(FEEL.to_json(evaluate("{a: 1 / 3}"))).must_equal '{"a":0.3333333333333333333333333333333333}'
      _(evaluate('from json("0.12345678901234567890")')).must_equal BigDecimal("0.1234567890123456789")
    end

    it "should serialize numbers without losing precision" do
      value = evaluate("{a: 1 / 3, b: 0.5, c: 2}")
      data = FEEL.serialize(value)
      _(data).must_equal({ "a" => { "$feel" => "number", "value" => "0.3333333333333333333333333333333333" }, "b" => 0.5, "c" => 2 })
      _(FEEL.deserialize(data.to_json)).must_equal value
    end

    # Expected values: Python's decimal with Context(prec=34,
    # rounding=ROUND_HALF_EVEN), i.e. IEEE 754 decimal128.
    describe "division" do
      it "should round a tie at digit 35 half to even" do
        # 312500000000000000000000000000000.25 (35 digits): half up would give .3
        _(evaluate("10000000000000000000000000000000008 / 32")).must_equal BigDecimal("312500000000000000000000000000000.2")
        # 312500000000000000000000000000000.75: rounds up either way
        _(evaluate("10000000000000000000000000000000024 / 32")).must_equal BigDecimal("312500000000000000000000000000000.8")
      end

      it "should round a quotient ending in 5 at digit 35 half to even" do
        # 1.0000000000000000000000000000000025
        _(evaluate("2.000000000000000000000000000000005 / 2")).must_equal BigDecimal("1.000000000000000000000000000000002")
        _(evaluate("-2.000000000000000000000000000000005 / 2")).must_equal BigDecimal("-1.000000000000000000000000000000002")
        # 1.0000000000000000000000000000000015
        _(evaluate("2.000000000000000000000000000000003 / 2")).must_equal BigDecimal("1.000000000000000000000000000000002")
        # 9999999999999999999999999999999999.5: carries to 10^34
        _(evaluate("99999999999999999999999999999999995 / 10")).must_equal 10**34
      end

      it "should round non-terminating quotients to 34 significant digits" do
        _(evaluate("2 / 3")).must_equal BigDecimal("0.6666666666666666666666666666666667")
        _(evaluate("0.000001 / 3")).must_equal BigDecimal("0.0000003333333333333333333333333333333333")
        _(evaluate("1 / 32")).must_equal 0.03125
      end

      it "should round the divisions of the list functions half to even" do
        _(evaluate("mean([2.000000000000000000000000000000005, 0])")).must_equal BigDecimal("1.000000000000000000000000000000002")
        _(evaluate("median([2.000000000000000000000000000000005, 0])")).must_equal BigDecimal("1.000000000000000000000000000000002")
      end

      it "should not depend on BigDecimal.mode" do
        BigDecimal.save_rounding_mode do
          BigDecimal.mode(BigDecimal::ROUND_MODE, :down)
          _(evaluate("2 / 3")).must_equal BigDecimal("0.6666666666666666666666666666666667")
          _(evaluate("10000000000000000000000000000000008 / 32")).must_equal BigDecimal("312500000000000000000000000000000.2")
        end
      end

      it "should keep addition, subtraction and multiplication exact" do
        _(evaluate("1000000000000000000000000000000000 + 0.0001")).must_equal BigDecimal("1000000000000000000000000000000000.0001")
        _(evaluate("1.0000000000000000000000000000000001 * 3")).must_equal BigDecimal("3.0000000000000000000000000000000003")
      end
    end
  end
end
