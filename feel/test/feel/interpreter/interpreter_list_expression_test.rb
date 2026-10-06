# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterListExpressionTest
#
# Note: suppressed failures (reportFailure) are not supported, only the result
# is checked.
module FEEL
  describe "interpreter list expression" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    HUGE_LIST = (1..10_000).to_a.freeze

    describe "A list" do
      it "should contain null if a variable doesn't exist" do
        _(evaluate("[1, x]")).must_equal [1, nil]
      end

      it "should be compared with '='" do
        _(evaluate("[] = []")).must_equal true
        _(evaluate("[1] = [1]")).must_equal true
        _(evaluate("[[1]] = [[1]]")).must_equal true
        _(evaluate("[{x:1}] = [{x:1}]")).must_equal true

        _(evaluate("[] = [1]")).must_equal false
        _(evaluate("[1] = []")).must_equal false
        _(evaluate("[1] = [2]")).must_equal false
        _(evaluate("[[1]] = [[2]]")).must_equal false
        _(evaluate("[{x:1}] = [{x:2}]")).must_equal false

        _(evaluate("[1] = [true]")).must_equal false
      end

      it "should be compared with '!='" do
        _(evaluate("[] != []")).must_equal false
        _(evaluate("[1] != [1]")).must_equal false
        _(evaluate("[[1]] != [[1]]")).must_equal false
        _(evaluate("[{x:1}] != [{x:1}]")).must_equal false

        _(evaluate("[] != [1]")).must_equal true
        _(evaluate("[1] != []")).must_equal true
        _(evaluate("[1] != [2]")).must_equal true
        _(evaluate("[[1]] != [[2]]")).must_equal true
        _(evaluate("[{x:1}] != [{x:2}]")).must_equal true

        _(evaluate("[1] != [true]")).must_equal true
      end

      it "should be accessed and compared" do
        _(evaluate("[1][1] = 1")).must_equal true
      end

      it "should return null if compare to not a list" do
        _(evaluate("[] = 1")).must_be_nil
      end
    end

    describe "A some-expression" do
      it "should return true if one item satisfies the condition" do
        _(evaluate("some x in [1,2,3] satisfies x > 2")).must_equal true

        _(evaluate("some x in xs satisfies x > 1", xs: [1, 2, 3])).must_equal true

        _(evaluate("some x in xs satisfies count(xs) > 2", xs: [1, 2, 3])).must_equal true

        _(evaluate("some x in [1,2], y in [2,3] satisfies x < y")).must_equal true
      end

      it "should return false if no item satisfies the condition" do
        _(evaluate("some x in [1,2,3] satisfies x > 3")).must_equal false

        _(evaluate("some x in xs satisfies x > 2", xs: [1, 2])).must_equal false

        _(evaluate("some x in [1,2], y in [1,1] satisfies x < y")).must_equal false
      end

      it "should return true if the range satisfies the condition" do
        _(evaluate("some x in 1..5 satisfies x > 3")).must_equal true
      end

      it "should return false if the range doesn't satisfy the condition" do
        _(evaluate("some x in 1..5 satisfies x > 10")).must_equal false
      end

      it "should return null if the value is not a list" do
        _(evaluate("some item in x satisfies x > 10")).must_be_nil

        _(evaluate("some item in x satisfies x > 10", x: 2)).must_be_nil
      end
    end

    describe "An every-expression" do
      it "should return true if all items satisfy the condition" do
        _(evaluate("every x in [1,2,3] satisfies x >= 1")).must_equal true

        _(evaluate("every x in xs satisfies x >= 1", xs: [1, 2, 3])).must_equal true

        _(evaluate("every x in [1,2], y in [3,4] satisfies x < y")).must_equal true
      end

      it "should return false if one item doesn't satisfy the condition" do
        _(evaluate("every x in [1,2,3] satisfies x >= 2")).must_equal false

        _(evaluate("every x in xs satisfies x >= 1", xs: [0, 1, 2, 3])).must_equal false

        _(evaluate("every x in [1,2], y in [2,3] satisfies x < y")).must_equal false
      end

      it "should return true if the range satisfies the condition" do
        _(evaluate("every x in 1..5 satisfies x < 10")).must_equal true
      end

      it "should return false if the range doesn't satisfy the condition" do
        _(evaluate("every x in 1..10 satisfies x < 5")).must_equal false
      end

      it "should return null if the value is not a list" do
        _(evaluate("every item in x satisfies x > 10")).must_be_nil

        _(evaluate("every item in x satisfies x > 10", x: 2)).must_be_nil
      end
    end

    describe "A for-expression" do
      it "should iterate over a list" do
        _(evaluate("for x in [1,2] return x * 2")).must_equal [2, 4]

        _(evaluate("for x in [1,2], y in [3,4] return x * y")).must_equal [3, 4, 6, 8]

        _(evaluate("for x in xs return x * 2", xs: [1, 2])).must_equal [2, 4]

        _(evaluate("for y in xs return index of([2, 3], y)", xs: [1, 2])).must_equal [[], [1]]
      end

      it "should iterate over a range" do
        _(evaluate("for x in 1..3 return x * 2")).must_equal [2, 4, 6]

        _(evaluate("for x in 1..n return x * 2", n: 3)).must_equal [2, 4, 6]
      end

      it "should iterate over a range in descending order" do
        _(evaluate("for x in 3..1 return x * 2")).must_equal [6, 4, 2]

        _(evaluate("for x in n..1 return x * 2", n: 3)).must_equal [6, 4, 2]
      end

      it "should access the partial result" do
        _(evaluate("for x in 1..5 return if (x = 1) then 1 else x + sum(partial)")).must_equal [1, 3, 7, 15, 31]

        _(evaluate("for i in 1..8 return if (i <= 2) then 1 else partial[-1] + partial[-2]")).must_equal [1, 1, 2, 3, 5, 8, 13, 21]
      end

      it "should return null if the value is not a list" do
        _(evaluate("for item in x return item * 2")).must_be_nil

        _(evaluate("for item in x return item * 2", x: 2)).must_be_nil
      end
    end

    describe "A huge list" do
      it "should be defined as range" do
        _(evaluate("for x in 1..10000 return x")).must_equal HUGE_LIST
      end

      it "should be checked with 'some'" do
        _(evaluate("some x in xs satisfies x >= 10000", xs: HUGE_LIST)).must_equal true

        _(evaluate("some x in xs satisfies x > 10000", xs: HUGE_LIST)).must_equal false
      end

      it "should be checked with 'some' (invalid condition)" do
        _(evaluate("some x in xs satisfies null", xs: HUGE_LIST)).must_be_nil
      end

      it "should be checked with 'every'" do
        _(evaluate("every x in xs satisfies x > 0", xs: HUGE_LIST)).must_equal true
      end

      it "should be checked with 'every' (invalid condition)" do
        _(evaluate("every x in xs satisfies null", xs: HUGE_LIST)).must_be_nil
      end

      it "should be iterated with `for`" do
        _(evaluate("for x in xs return x", xs: HUGE_LIST)).must_equal HUGE_LIST
      end

      it "should be filtered" do
        _(evaluate("xs[item <= 5000]", xs: HUGE_LIST)).must_equal HUGE_LIST.take(5000)
      end

      it "should be accessed by index" do
        _(evaluate("xs[-1]", xs: HUGE_LIST)).must_equal HUGE_LIST.last
      end
    end

    describe "A filter expression" do
      it "should access the item" do
        _(evaluate("[1,2,3,4][item > 2]")).must_equal [3, 4]

        _(evaluate("xs [item > 2]", xs: [1, 2, 3, 4])).must_equal [3, 4]
      end

      it "should compare the item with null" do
        # items that are not comparable to null are ignored
        _(evaluate("[1,2,3,4][item > null]")).must_equal []

        # items that are not comparable to null are ignored
        _(evaluate("[1,2,3,4][item < null]")).must_equal []
      end

      it "should compare the item if the item is null" do
        # null is not comparable to 2, so it's ignored
        _(evaluate("[1,2,null,4][item > 2]")).must_equal [4]

        # null is the only item for which the comparison returns true
        _(evaluate("[1,2,null,4][item = null]")).must_equal [nil]
      end

      it "should compare the item if the item is a missing variable" do
        # null is the only item for which the comparison returns true
        _(evaluate("[1,2,x,4][item = null]")).must_equal [nil]

        # missing variable becomes null, so same as direct null item
        _(evaluate("[1,2,x,4][item > 2]")).must_equal [4]
      end

      it "should access an item by index" do
        _(evaluate("[1,2,3,4][1]")).must_equal 1
        _(evaluate("[1,2,3,4][2]")).must_equal 2

        _(evaluate("[1,2,3,4][-1]")).must_equal 4
        _(evaluate("[1,2,3,4][-2]")).must_equal 3

        _(evaluate("[1,2,3,4][5]")).must_be_nil
        _(evaluate("[1,2,3,4][-5]")).must_be_nil

        _(evaluate("[1,2,3,4][i]", i: 2)).must_equal 2
        _(evaluate("[1,2,3,4][i]", i: -2)).must_equal 3
      end

      it "should compare the item with a boolean expression" do
        _(evaluate("[1,2,3,4][odd(item)]")).must_equal [1, 3]

        _(evaluate("[1,2,3,4][even(item)]")).must_equal [2, 4]
      end

      it "should access an item by a numeric function" do
        _(evaluate("[1,2,3,4][abs(1)]")).must_equal 1

        _(evaluate("[1,2,3,4][modulo(2,4)]")).must_equal 2
      end

      it "should compare the item with a custom boolean function" do
        function_invocations = []
        f = ->(x) {
          function_invocations << x
          x == 3
        }

        _(evaluate("[1,2,3,4][f(item)]", f: f)).must_equal [3]

        _(function_invocations).must_equal [1, 2, 3, 4]
      end

      it "should access the item with a custom numeric function" do
        function_invocations = []
        f = ->(x) {
          function_invocations << x
          3
        }

        _(evaluate("[1,2,3,4][f(item)]", f: f)).must_equal 3

        _(function_invocations).must_equal [1]
      end

      it "should access a nested item by index (from literal)" do
        _(evaluate("[[1]][1][1]")).must_equal 1
        _(evaluate("[[[1]]][1][1][1]")).must_equal 1
        _(evaluate("[[[[1]]]][1][1][1][1]")).must_equal 1
      end

      it "should access a nested item by index (from variable)" do
        list_of_lists = [[1]]

        _(evaluate("xs[1][1]", xs: list_of_lists)).must_equal 1
        _(evaluate("xs[1][1][1]", xs: [list_of_lists])).must_equal 1
        _(evaluate("xs[1][1][1][1]", xs: [[list_of_lists]])).must_equal 1
      end

      it "should access a nested item by index (from function invocation)" do
        _(evaluate("append([], [1])[1][1]")).must_equal 1
        _(evaluate("append([], [[1]])[1][1][1]")).must_equal 1
        _(evaluate("append([], [[[1]]])[1][1][1][1]")).must_equal 1
      end

      it "should access a nested item by index (from path)" do
        list_of_lists = [[1]]

        _(evaluate("x.y[1][1]", x: { "y" => list_of_lists })).must_equal 1
        _(evaluate("x.y[1][1][1]", x: { "y" => [list_of_lists] })).must_equal 1
        _(evaluate("x.y[1][1][1][1]", x: { "y" => [[list_of_lists]] })).must_equal 1
      end

      it "should access a nested item by index (from context projection)" do
        _(evaluate("{x:[[1]]}.x[1][1]")).must_equal 1
        _(evaluate("{x:[[[1]]]}.x[1][1][1]")).must_equal 1
        _(evaluate("{x:[[[[1]]]]}.x[1][1][1][1]")).must_equal 1
      end

      it "should access a nested item by index (in a context)" do
        list_of_lists = [[1]]

        _(evaluate("{z: x.y[1][1]}.z", x: { "y" => list_of_lists })).must_equal 1
        _(evaluate("{z: x.y[1][1][1]}.z", x: { "y" => [list_of_lists] })).must_equal 1
        _(evaluate("{z: x.y[1][1][1][1]}.z", x: { "y" => [[list_of_lists]] })).must_equal 1
      end

      it "should ignore items if the filter doesn't return a boolean or a number" do
        _(evaluate(' [1,2,3,4]["not a valid filter"] ')).must_equal []
        _(evaluate("[1,2,3,4][if item < 3 then true else null]")).must_equal [1, 2]
      end

      it "should access an item property if the context contains a variable with the same name" do
        expression = <<~FEEL
          sum({"loans" : [
                {"loanId" : "AAA001", "amount" : 10},
                {"loanId" : "AAA002", "amount" : 20},
                {"loanId" : "AAA001", "amount" : 50}
              ]}.loans[loanId = id].amount)
        FEEL
        _(evaluate(expression, id: "AAA002", loanId: "AAA002")).must_equal 20
      end

      # Not applicable: "access an item property if the custom context contains a variable with the same name" uses a Scala CustomContext

      it "should return null if the value is not a list" do
        _(evaluate("x[even(item)]")).must_be_nil

        _(evaluate("x[even(item)]", x: 2)).must_be_nil

        _(evaluate("x[1]")).must_be_nil
      end

      it "should compute a long list" do
        _(evaluate('count(for x in 0..1000000 return "Hi there")')).must_equal 1_000_001
      end
    end
  end
end
