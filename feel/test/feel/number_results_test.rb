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
  end
end
