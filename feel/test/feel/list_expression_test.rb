# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterListExpressionTest, InterpreterExpressionTest
module FEEL
  describe "list expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe :list do
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
        _(evaluate("[{x:1}] != [{x:1}]")).must_equal false

        _(evaluate("[] != [1]")).must_equal true
        _(evaluate("[1] != [2]")).must_equal true
        _(evaluate("[{x:1}] != [{x:2}]")).must_equal true
      end

      it "should be accessed and compared" do
        _(evaluate("[1][1] = 1")).must_equal true
      end
    end

    describe :some_expression do
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

      it "should iterate over a range" do
        _(evaluate("some x in 1..5 satisfies x > 3")).must_equal true
        _(evaluate("some x in 1..5 satisfies x > 10")).must_equal false
      end

      it "should return null if the value is not a list" do
        _(evaluate("some item in x satisfies x > 10")).must_be_nil
        _(evaluate("some item in x satisfies x > 10", x: 2)).must_be_nil
      end

      it "should return null if the condition is not a boolean" do
        _(evaluate("some x in xs satisfies null", xs: [1, 2, 3])).must_be_nil
      end

      it "should support the examples from the specification" do
        _(evaluate("some i in [1, 2, 3] satisfies i > 2")).must_equal true
        _(evaluate("some i in [1, 2, 3] satisfies i > 4")).must_equal false
      end
    end

    describe :every_expression do
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

      it "should iterate over a range" do
        _(evaluate("every x in 1..5 satisfies x < 10")).must_equal true
        _(evaluate("every x in 1..10 satisfies x < 5")).must_equal false
      end

      it "should return null if the value is not a list" do
        _(evaluate("every item in x satisfies x > 10")).must_be_nil
        _(evaluate("every item in x satisfies x > 10", x: 2)).must_be_nil
      end

      it "should return null if the condition is not a boolean" do
        _(evaluate("every x in xs satisfies null", xs: [1, 2, 3])).must_be_nil
      end

      it "should support the examples from the specification" do
        _(evaluate("every i in [1, 2, 3] satisfies i > 1")).must_equal false
        _(evaluate("every i in [1, 2, 3] satisfies i > 0")).must_equal true
      end
    end

    describe :for_expression do
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

      it "should support the examples from the specification" do
        _(evaluate("for i in [1, 2, 3] return i * i")).must_equal [1, 4, 9]
        _(evaluate("for i in 1..3 return i * i")).must_equal [1, 4, 9]
        _(evaluate("for i in [1,2,3], j in [1,2,3] return i*j")).must_equal [1, 2, 3, 2, 4, 6, 3, 6, 9]
      end

      it "should iterate over a huge list" do
        huge_list = (1..10_000).to_a
        _(evaluate("for x in 1..10000 return x")).must_equal huge_list
        _(evaluate("for x in xs return x", xs: huge_list)).must_equal huge_list
        _(evaluate("count(for x in 0..100000 return \"Hi there\")")).must_equal 100_001
      end
    end

    describe :filter_expression do
      it "should access the item" do
        _(evaluate("[1,2,3,4][item > 2]")).must_equal [3, 4]
        _(evaluate("xs [item > 2]", xs: [1, 2, 3, 4])).must_equal [3, 4]
      end

      it "should compare the item with null" do
        _(evaluate("[1,2,3,4][item > null]")).must_equal []
        _(evaluate("[1,2,3,4][item < null]")).must_equal []
      end

      it "should compare the item if the item is null" do
        _(evaluate("[1,2,null,4][item > 2]")).must_equal [4]
        _(evaluate("[1,2,null,4][item = null]")).must_equal [nil]
      end

      it "should compare the item if the item is a missing variable" do
        _(evaluate("[1,2,x,4][item = null]")).must_equal [nil]
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

      it "should filter with a boolean function" do
        _(evaluate("[1,2,3,4][odd(item)]")).must_equal [1, 3]
        _(evaluate("[1,2,3,4][even(item)]")).must_equal [2, 4]
      end

      it "should access an item by a numeric function" do
        _(evaluate("[1,2,3,4][abs(1)]")).must_equal 1
        _(evaluate("[1,2,3,4][modulo(2,4)]")).must_equal 2
      end

      it "should filter with a custom boolean function" do
        invocations = []
        f = ->(x) { invocations << x; x == 3 }
        _(evaluate("[1,2,3,4][f(item)]", f: f)).must_equal [3]
        _(invocations).must_equal [1, 2, 3, 4]
      end

      it "should access the item with a custom numeric function" do
        invocations = []
        f = ->(x) { invocations << x; 3 }
        _(evaluate("[1,2,3,4][f(item)]", f: f)).must_equal 3
        _(invocations).must_equal [1]
      end

      it "should access a nested item by index" do
        _(evaluate("[[1]][1][1]")).must_equal 1
        _(evaluate("[[[1]]][1][1][1]")).must_equal 1
        _(evaluate("xs[1][1]", xs: [[1]])).must_equal 1
        _(evaluate("append([], [1])[1][1]")).must_equal 1
        _(evaluate("x.y[1][1]", x: { y: [[1]] })).must_equal 1
        _(evaluate("{x:[[1]]}.x[1][1]")).must_equal 1
        _(evaluate("{z: x.y[1][1]}.z", x: { y: [[1]] })).must_equal 1
      end

      it "should ignore items if the filter doesn't return a boolean or a number" do
        _(evaluate('[1,2,3,4]["not a valid filter"]')).must_equal []
        _(evaluate("[1,2,3,4][if item < 3 then true else null]")).must_equal [1, 2]
      end

      it "should access item properties if the context contains a variable with the same name" do
        expression = <<~FEEL
          sum({"loans" : [
            {"loanId" : "AAA001", "amount" : 10},
            {"loanId" : "AAA002", "amount" : 20},
            {"loanId" : "AAA001", "amount" : 50}
          ]}.loans[loanId = id].amount)
        FEEL
        _(evaluate(expression, id: "AAA002", loanId: "AAA002")).must_equal 20
      end

      it "should filter a list of contexts from variables" do
        orders = [{ id: 1, total: 50 }, { id: 2, total: 150 }, { id: 3, total: 250 }]
        _(evaluate("orders[total > 100].id", orders: orders)).must_equal [2, 3]
        _(evaluate("orders[item.total > 100].id", orders: orders)).must_equal [2, 3]
      end

      it "should return null if the value is not a list" do
        _(evaluate("x[even(item)]")).must_be_nil
        _(evaluate("x[even(item)]", x: 2)).must_be_nil
        _(evaluate("x[1]")).must_be_nil
      end

      it "should be filtered by index on a huge list" do
        huge_list = (1..10_000).to_a
        _(evaluate("xs[item <= 5000]", xs: huge_list)).must_equal huge_list.take(5000)
        _(evaluate("xs[-1]", xs: huge_list)).must_equal 10_000
      end
    end

    describe :path_expression do
      it "should access nested paths" do
        _(evaluate("{x:{y:1}}.x.y")).must_equal 1
        _(evaluate("{x:{y:{z:1}}}.x.y.z")).must_equal 1
        _(evaluate("({x:{y:{z:1}}}).x.y.z")).must_equal 1
        _(evaluate("({x:{y:{z:1}}}.x).y.z")).must_equal 1
        _(evaluate("({x:{y:{z:1}}}.x.y).z")).must_equal 1
      end

      it "should combine nested filter and path expressions" do
        _(evaluate("[{x:{y:1}},{x:{y:2}},{x:{y:3}}].x.y[2]")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}]).x.y[2]")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}].x).y[2]")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}].x.y)[2]")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}]).x[2].y")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}])[2].x.y")).must_equal 2
        _(evaluate("[{x:[1,2]},{x:[3,4]},{x:[5,6]}][2].x[1]")).must_equal 3
        _(evaluate("([{x:[1,2]},{x:[3,4]},{x:[5,6]}]).x[2][1]")).must_equal 3
        _(evaluate("([{x:[1,2]},{x:[3,4]},{x:[5,6]}].x)[2][1]")).must_equal 3
        _(evaluate("([{x:[1,2]},{x:[3,4]},{x:[5,6]}].x[2])[1]")).must_equal 3
      end

      it "should support parentheses" do
        _(evaluate("([1,2,3])[1]")).must_equal 1
        _(evaluate("({x:1}).x")).must_equal 1
        _(evaluate("{x:(1)}.x")).must_equal 1
        _(evaluate("[1,2,3,4][(1)]")).must_equal 1
        _(evaluate("{x:(xs[1])}.x", xs: [1, 2, 3])).must_equal 1
        _(evaluate("{x:(xs)[1]}.x", xs: [1, 2, 3])).must_equal 1
        _(evaluate("{x:(xs)}.x", xs: [1, 2, 3])).must_equal [1, 2, 3]
      end

      it "should access properties of function results" do
        _(evaluate("date(2019,09,17).year")).must_equal 2019
        _(evaluate("index of([1,2,3,2],2)[1]")).must_equal 2
      end
    end
  end
end
