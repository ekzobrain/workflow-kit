# frozen_string_literal: true

require "test_helper"

# List expression tests that are not covered by the ported feel-scala tests
# (see test/feel/interpreter/interpreter_list_expression_test.rb).
module FEEL
  describe "list expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe :some_expression do
      it "should return null if the condition is not a boolean" do
        _(evaluate("some x in xs satisfies null", xs: [1, 2, 3])).must_be_nil
      end

      it "should support the examples from the specification" do
        _(evaluate("some i in [1, 2, 3] satisfies i > 2")).must_equal true
        _(evaluate("some i in [1, 2, 3] satisfies i > 4")).must_equal false
      end
    end

    describe :every_expression do
      it "should return null if the condition is not a boolean" do
        _(evaluate("every x in xs satisfies null", xs: [1, 2, 3])).must_be_nil
      end

      it "should support the examples from the specification" do
        _(evaluate("every i in [1, 2, 3] satisfies i > 1")).must_equal false
        _(evaluate("every i in [1, 2, 3] satisfies i > 0")).must_equal true
      end
    end

    describe :for_expression do
      it "should support the examples from the specification" do
        _(evaluate("for i in [1, 2, 3] return i * i")).must_equal [1, 4, 9]
        _(evaluate("for i in 1..3 return i * i")).must_equal [1, 4, 9]
        _(evaluate("for i in [1,2,3], j in [1,2,3] return i*j")).must_equal [1, 2, 3, 2, 4, 6, 3, 6, 9]
      end
    end

    describe :filter_expression do
      it "should filter a list of contexts from variables" do
        orders = [{ id: 1, total: 50 }, { id: 2, total: 150 }, { id: 3, total: 250 }]
        _(evaluate("orders[total > 100].id", orders: orders)).must_equal [2, 3]
        _(evaluate("orders[item.total > 100].id", orders: orders)).must_equal [2, 3]
      end

      it "should prefer a context entry named item over the implicit item variable" do
        _(evaluate("[{item: 1}, {item: 2}][item > 1]")).must_equal [{ "item" => 2 }]
      end
    end
  end
end
