# frozen_string_literal: true

require "test_helper"

# Unary tests that are not covered by the ported feel-scala tests (see
# test/feel/interpreter/interpreter_unary_test.rb).
#
# Note: FEEL.test returns a boolean, a null result of the unary tests is
# reported as false (i.e. the input entry doesn't match).
module FEEL
  describe "unary tests expressions" do
    def test(input, text, variables = {})
      FEEL.test(input, text, variables: variables)
    end

    it "should support open intervals with reversed brackets" do
      _(test(2, "]2..4]")).must_equal false
      _(test(3, "]2..4]")).must_equal true
      _(test(4, "[2..4[")).must_equal false
      _(test(3, "[2..4[")).must_equal true
    end

    it "should compare a context with symbol keys" do
      _(test({ x: 1 }, "{x:1}")).must_equal true
    end

    it "should support between and in with the input value" do
      _(test(5, "? between 1 and 10")).must_equal true
      _(test(5, "? in [1..3]")).must_equal false
    end
  end
end
