# frozen_string_literal: true

require "test_helper"

module FEEL
  describe "errors" do
    it "should have FEEL::Error as base class" do
      [SyntaxError, EvaluationError, SerializationError].each do |error|
        _(error.ancestors).must_include Error
      end
      _(Error.superclass).must_equal StandardError
    end

    it "should raise errors that can be rescued as FEEL::Error" do
      _ { FEEL.evaluate("1 +") }.must_raise Error
      _ { FEEL.test(1, "[1..") }.must_raise Error
      _ { FEEL.serialize(Object.new) }.must_raise Error
      _ { FEEL.deserialize({ "$feel" => "date", "value" => "x" }) }.must_raise Error

      FEEL.config.strict = true
      _ { FEEL.evaluate("missing") }.must_raise Error
    end

    it "should keep the specific error classes" do
      _ { FEEL.evaluate("1 +") }.must_raise SyntaxError
      _ { FEEL.serialize(->(x) { x }) }.must_raise SerializationError
    end
  end
end
