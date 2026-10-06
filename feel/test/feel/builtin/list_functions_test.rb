# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinListFunctionsTest
module FEEL
  describe "built-in list functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    # `and` and `or` are reserved words in the grammar, so `and(...)` and
    # `or(...)` can't be parsed yet as function invocations.
    def skip_unless_and_or_parsable
      return if LiteralExpression.new(text: "and(true)").valid?

      skip "and()/or() can't be parsed: 'and'/'or' are reserved words in the grammar (function_name rule)"
    end

    describe "A list contains() function" do
      it "return if the list contains Number" do
        _(evaluate(" list contains([1,2,3], 2) ")).must_equal true

        _(evaluate(" list contains([1,2,3], 4) ")).must_equal false
      end

      it "return if the list contains String" do
        _(evaluate(' list contains(["a","b"], "a") ')).must_equal true

        _(evaluate(' list contains(["a","b"], "c") ')).must_equal false
      end
    end

    describe "A count() function" do
      it "return the size of a list" do
        _(evaluate(" count([1,2,3]) ")).must_equal 3
      end
    end

    describe "A min() function" do
      it "return the null if empty list" do
        _(evaluate(" min([]) ")).must_be_nil
      end

      it "return the minimum item of numbers" do
        _(evaluate(" min([1,2,3]) ")).must_equal 1
        _(evaluate(" min(1,2,3) ")).must_equal 1
      end

      it "return the minimum item of date" do
        _(evaluate(' min([date("2017-01-01"), date("2018-01-01"), date("2019-01-01")]) '))
          .must_equal Date.parse("2017-01-01")
      end

      it "return null if value is not comparable" do
        _(evaluate(" min([true, false]) ")).must_be_nil
      end
    end

    describe "A max() function" do
      it "return the null if empty list" do
        _(evaluate(" max([]) ")).must_be_nil
      end

      it "return the maximum item of numbers" do
        _(evaluate(" max([1,2,3]) ")).must_equal 3
        _(evaluate(" max(1,2,3) ")).must_equal 3
      end

      it "return the maximum item of date" do
        _(evaluate(' max([date("2017-01-01"), date("2018-01-01"), date("2019-01-01")]) '))
          .must_equal Date.parse("2019-01-01")
      end

      it "return null if value is not comparable" do
        _(evaluate(" max([true, false]) ")).must_be_nil
      end
    end

    describe "A sum() function" do
      it "return null if empty list" do
        _(evaluate(" sum([]) ")).must_be_nil
      end

      it "return sum of numbers" do
        _(evaluate(" sum([1,2,3]) ")).must_equal 6
        _(evaluate(" sum(1,2,3) ")).must_equal 6
      end
    end

    describe "A mean() function" do
      it "return null if empty list" do
        _(evaluate(" mean([]) ")).must_be_nil
      end

      it "return mean of numbers" do
        _(evaluate(" mean([1,2,3]) ")).must_equal 2
        _(evaluate(" mean(1,2,3) ")).must_equal 2
      end
    end

    describe "A median() function" do
      it "return null if empty list" do
        _(evaluate(" median([]) ")).must_be_nil
      end

      it "return the median of numbers" do
        _(evaluate(" median(8, 2, 5, 3, 4) ")).must_equal 4
        _(evaluate(" median([6, 1, 2, 3]) ")).must_equal 2.5
      end
    end

    describe "A stddev() function" do
      it "return null if empty list" do
        _(evaluate(" stddev([]) ")).must_be_nil
      end

      it "return the standard deviation" do
        _(evaluate(" stddev(2, 4, 7, 5) ")).must_equal 2.0816659994661326
        _(evaluate(" stddev([2, 4, 7, 5]) ")).must_equal 2.0816659994661326
      end
    end

    describe "A mode() function" do
      it "return empty list if empty list" do
        _(evaluate(" mode([]) ")).must_equal []
      end

      it "return the mode of the list" do
        _(evaluate(" mode(6, 3, 9, 6, 6) ")).must_equal [6]
        _(evaluate(" mode([6, 1, 9, 6, 1]) ")).must_equal [1, 6]
      end
    end

    describe "A and() / all() function" do
      it "return true if empty list" do
        _(evaluate(" all([]) ")).must_equal true

        skip_unless_and_or_parsable
        _(evaluate(" and([]) ")).must_equal true
      end

      it "return true if all items are true" do
        _(evaluate(" all([false,null,true]) ")).must_equal false
        _(evaluate(" all(false,null,true) ")).must_equal false
        _(evaluate(" all([true,true]) ")).must_equal true
        _(evaluate(" all(true,true) ")).must_equal true

        skip_unless_and_or_parsable
        _(evaluate(" and([false,null,true]) ")).must_equal false
        _(evaluate(" and(false,null,true) ")).must_equal false
        _(evaluate(" and([true,true]) ")).must_equal true
        _(evaluate(" and(true,true) ")).must_equal true
      end

      it "return null if argument is invalid" do
        _(evaluate("all(0)")).must_be_nil

        skip_unless_and_or_parsable
        _(evaluate("and(0)")).must_be_nil
      end

      it "return null if one item is not a boolean value" do
        _(evaluate("all(true, null, true)")).must_be_nil

        skip_unless_and_or_parsable
        _(evaluate("and(true, null, true)")).must_be_nil
      end

      it "return true if all items are true (huge list)" do
        huge_list = Array.new(10_000, true)

        _(evaluate("all(xs)", xs: huge_list)).must_equal true
      end

      it "return null if items are not boolean values (huge list)" do
        huge_list = (1..10_000).to_a

        _(evaluate("all(xs)", xs: huge_list)).must_be_nil
      end
    end

    describe "A or() / any() function" do
      it "return false if empty list" do
        _(evaluate(" any([]) ")).must_equal false

        skip_unless_and_or_parsable
        _(evaluate(" or([]) ")).must_equal false
      end

      it "return false if all items are false" do
        _(evaluate(" any([false,null,true]) ")).must_equal true
        _(evaluate(" any(false,null,true) ")).must_equal true
        _(evaluate(" any([false,false]) ")).must_equal false
        _(evaluate(" any(false,false) ")).must_equal false

        skip_unless_and_or_parsable
        _(evaluate(" or([false,null,true]) ")).must_equal true
        _(evaluate(" or(false,null,true) ")).must_equal true
        _(evaluate(" or([false,false]) ")).must_equal false
        _(evaluate(" or(false,false) ")).must_equal false
      end

      it "return null if argument is invalid" do
        _(evaluate("any(0)")).must_be_nil

        skip_unless_and_or_parsable
        _(evaluate("or(0)")).must_be_nil
      end

      it "return null if one item is not a boolean value" do
        _(evaluate("any(false, null, false)")).must_be_nil

        skip_unless_and_or_parsable
        _(evaluate("or(false, null, false)")).must_be_nil
      end

      it "return false if all items are false (huge list)" do
        huge_list = Array.new(10_000, false)

        _(evaluate("any(xs)", xs: huge_list)).must_equal false
      end

      it "return null if items are not boolean values (huge list)" do
        huge_list = (1..10_000).to_a

        _(evaluate("any(xs)", xs: huge_list)).must_be_nil
      end
    end

    describe "A sublist() function" do
      it "return list starting with _" do
        _(evaluate(" sublist([1,2,3], 2) ")).must_equal [2, 3]
      end

      it "return list starting with _ and length _" do
        _(evaluate(" sublist([1,2,3], 1, 2) ")).must_equal [1, 2]
      end

      it "return null if the start position is 0" do
        _(evaluate(" sublist([1,2,3], 0) ")).must_be_nil

        _(evaluate(" sublist([1,2,3], 0, 2) ")).must_be_nil
      end
    end

    describe "A append() function" do
      it "return list with item appended" do
        _(evaluate(" append([1,2], 3) ")).must_equal [1, 2, 3]
        _(evaluate(" append([1], 2, 3) ")).must_equal [1, 2, 3]
      end
    end

    describe "A concatenate() function" do
      it "return list with item appended" do
        _(evaluate(" concatenate([1,2],[3]) ")).must_equal [1, 2, 3]
        _(evaluate(" concatenate([1],[2],[3]) ")).must_equal [1, 2, 3]
      end
    end

    describe "A insert before() function" do
      it "return list with new item at _" do
        _(evaluate(" insert before([1,3],2,2) ")).must_equal [1, 2, 3]
      end

      it "return null if the position is 0" do
        _(evaluate(" insert before([1,3],0,2) ")).must_be_nil
      end
    end

    describe "A remove() function" do
      it "return list with item at _ removed" do
        _(evaluate(" remove([1,1,3],2) ")).must_equal [1, 3]
      end

      it "return null if the position is 0" do
        _(evaluate(" remove([1,2,3], 0) ")).must_be_nil
      end
    end

    describe "A reverse() function" do
      it "reverse the list" do
        _(evaluate(" reverse([1,2,3]) ")).must_equal [3, 2, 1]
      end
    end

    describe "A index of() function" do
      it "return empty list if no match" do
        _(evaluate(" index of([1,2,3,2], 4) ")).must_equal []
      end

      it "return list of positions containing the match" do
        _(evaluate(" index of([1,2,3,2], 1) ")).must_equal [1]
        _(evaluate(" index of([1,2,3,2], 2) ")).must_equal [2, 4]
        _(evaluate(" index of([1,2,3,2], 3) ")).must_equal [3]
      end
    end

    describe "A union() function" do
      it "concatenate with duplicate removal" do
        _(evaluate(" union([1,2],[2,3]) ")).must_equal [1, 2, 3]
        _(evaluate(" union([1,2],[2,3], [4]) ")).must_equal [1, 2, 3, 4]
      end

      it "invoked with named parameter" do
        _(evaluate(" union(lists: [[1,2],[2,3]]) ")).must_equal [1, 2, 3]
      end

      it "remove duplicated context values" do
        _(evaluate("union([{a:1},{a:2}],[{a:1},{b:3}])")).must_equal(
          [{ "a" => 1 }, { "a" => 2 }, { "b" => 3 }],
        )

        _(evaluate("union([{a:1},{a:null}],[{a:null},{b:2}])")).must_equal(
          [{ "a" => 1 }, { "a" => nil }, { "b" => 2 }],
        )

        _(evaluate("union([{a:1},{}],[{},{b:2}])")).must_equal(
          [{ "a" => 1 }, {}, { "b" => 2 }],
        )

        _(evaluate("union([{a:1,b:{c:2}}, {a:1,b:{c:3}}], [{a:1,b:{c:2}}, {a:1,b:{c:3},d:4}])")).must_equal(
          [
            { "a" => 1, "b" => { "c" => 2 } },
            { "a" => 1, "b" => { "c" => 3 } },
            { "a" => 1, "b" => { "c" => 3 }, "d" => 4 },
          ],
        )
      end

      it "remove duplicated list values" do
        _(evaluate(" union([[1],[2]],[[3],[2]]) ")).must_equal [[1], [2], [3]]

        _(evaluate(" union([[1],[null]],[[1],[null]]) ")).must_equal [[1], [nil]]

        _(evaluate(" union([[1],[]],[[],[2]]) ")).must_equal [[1], [], [2]]

        _(evaluate(" union([[1,2],[4,5]],[[1,2],[4]]) ")).must_equal [[1, 2], [4, 5], [4]]
      end

      it "remove duplicated null values" do
        _(evaluate(" union([1,null],[2,null]) ")).must_equal [1, nil, 2]
      end
    end

    describe "A distinct values() function" do
      it "remove duplicates" do
        _(evaluate(" distinct values([1,2,3,2,1]) ")).must_equal [1, 2, 3]
      end

      it "invoked with named parameter" do
        _(evaluate(" distinct values(list: [1,2,3,2,1]) ")).must_equal [1, 2, 3]
      end

      it "remove duplicated context values" do
        _(evaluate("distinct values([{a:1},{a:2},{a:1},{b:3}])")).must_equal(
          [{ "a" => 1 }, { "a" => 2 }, { "b" => 3 }],
        )

        _(evaluate("distinct values([{a:1},{a:null},{a:null}])")).must_equal(
          [{ "a" => 1 }, { "a" => nil }],
        )

        _(evaluate("distinct values([{a:1},{},{}])")).must_equal(
          [{ "a" => 1 }, {}],
        )

        _(evaluate("distinct values([{a:1,b:{c:2}}, {a:1,b:{c:3}}, {a:1,b:{c:2}}, {a:1,b:{c:3},d:4}])")).must_equal(
          [
            { "a" => 1, "b" => { "c" => 2 } },
            { "a" => 1, "b" => { "c" => 3 } },
            { "a" => 1, "b" => { "c" => 3 }, "d" => 4 },
          ],
        )
      end

      it "remove duplicated list values" do
        _(evaluate(" distinct values([[1],[2],[3],[2]]) ")).must_equal [[1], [2], [3]]

        _(evaluate(" distinct values([[1],[null],[1],[null]]) ")).must_equal [[1], [nil]]

        _(evaluate(" distinct values([[1],[],[]]) ")).must_equal [[1], []]

        _(evaluate(" distinct values([[1,2],[4,5],[1,2],[4]]) ")).must_equal [[1, 2], [4, 5], [4]]
      end

      it "remove duplicated null values" do
        _(evaluate(" distinct values([1,null,2,null]) ")).must_equal [1, nil, 2]
      end

      it "preserve the order" do
        _(evaluate(" distinct values([1,2,3,4,2,3,1]) ")).must_equal [1, 2, 3, 4]
      end
    end

    describe "A duplicate values() function" do
      it "return duplicate values" do
        _(evaluate(" duplicate values([1,2,3,2,1]) ")).must_equal [1, 2]
      end

      it "invoked with named parameter" do
        _(evaluate(" duplicate values(list: [1,2,3,2,1]) ")).must_equal [1, 2]
      end

      it "return an empty list if there are no duplicates" do
        _(evaluate(" duplicate values(list: [1,2,3,4,5]) ")).must_equal []
      end

      it "return duplicated context values" do
        _(evaluate("duplicate values([{a:1},{a:2},{a:1},{a:2},{b:3}])")).must_equal(
          [{ "a" => 1 }, { "a" => 2 }],
        )

        _(evaluate("duplicate values([{a:1},{a:null},{a:null},{b:2},{a:1}])")).must_equal(
          [{ "a" => 1 }, { "a" => nil }],
        )

        _(evaluate("duplicate values([{a:1},{},{},{b:2},{a:1}])")).must_equal(
          [{ "a" => 1 }, {}],
        )

        _(evaluate("duplicate values([{a:1,b:{c:2}}, {a:1,b:{c:3}}, {a:1,b:{c:2}}, {a:1,b:{c:3},d:4}, {a:1}])")).must_equal(
          [{ "a" => 1, "b" => { "c" => 2 } }],
        )
      end

      it "return duplicated list values" do
        _(evaluate(" duplicate values([[1],[2],[3],[2],[3]]) ")).must_equal [[2], [3]]

        _(evaluate(" duplicate values([[1],[null],[1],[null],[2]]) ")).must_equal [[1], [nil]]

        _(evaluate(" duplicate values([[1],[],[],[2],[1]]) ")).must_equal [[1], []]

        _(evaluate(" duplicate values([[1,2],[4,5],[1,2],[4]]) ")).must_equal [[1, 2]]
      end

      it "return duplicated null values" do
        _(evaluate(" duplicate values([1,null,2,null,2]) ")).must_equal [nil, 2]
      end

      it "preserve the order" do
        _(evaluate(" duplicate values([1,2,3,4,2,3,1]) ")).must_equal [1, 2, 3]

        _(evaluate(" duplicate values([1,2,3,4,3,1,2]) ")).must_equal [1, 2, 3]
      end
    end

    describe "A flatten() function" do
      it "flatten nested lists" do
        _(evaluate(" flatten([[1,2],[[3]], 4]) ")).must_equal [1, 2, 3, 4]
      end

      it "flatten a huge list of lists" do
        huge_list = (1..10_000).map { |i| [i] }

        _(evaluate("flatten(xs)", xs: huge_list)).must_equal huge_list.flatten
      end
    end

    describe "A sort() function" do
      it "sort list of numbers" do
        _(evaluate(" sort(list: [3,1,4,5,2], precedes: function(x,y) x < y) ")).must_equal [1, 2, 3, 4, 5]
      end
    end

    describe "A product() function" do
      it "return null if empty list" do
        _(evaluate(" product([]) ")).must_be_nil
      end

      it "return product of numbers" do
        _(evaluate(" product([2,3,4]) ")).must_equal 24
        _(evaluate(" product(2,3,4) ")).must_equal 24
      end
    end

    describe "A join function" do
      it "return an empty string if the input list is empty" do
        _(evaluate(" string join([]) ")).must_equal ""
      end

      it "return an empty string if the input list is empty and a delimiter is defined" do
        _(evaluate(' string join([], "X") ')).must_equal ""
      end

      it "return joined strings" do
        _(evaluate(' string join(["foo","bar","baz"]) ')).must_equal "foobarbaz"
      end

      it "return joined strings when delimiter is null" do
        _(evaluate(' string join(["foo","bar","baz"], null) ')).must_equal "foobarbaz"
      end

      it "return original string when list contains a single entry" do
        _(evaluate(' string join(["a"], "X") ')).must_equal "a"
      end

      it "ignore null strings" do
        _(evaluate(' string join(["foo", null, "baz"], null) ')).must_equal "foobaz"
      end

      it "ignore null strings with delimiter" do
        _(evaluate(' string join(["foo", null, "baz"], "X") ')).must_equal "fooXbaz"
      end

      it "return joined strings with custom separator" do
        _(evaluate(' string join(["foo","bar","baz"], "::") ')).must_equal "foo::bar::baz"
      end

      it "return joined strings with custom separator, a prefix and a suffix" do
        _(evaluate(' string join(["foo","bar","baz"], "::", "hello-", "-goodbye")  ')).must_equal "hello-foo::bar::baz-goodbye"
      end

      it "return null if the list contains other values than strings" do
        _(evaluate(' string join(["foo", 123, "bar"]) ')).must_be_nil
      end
    end

    describe "A list is empty() function" do
      it "return if the list is empty" do
        _(evaluate(" is empty([]) ")).must_equal true
        _(evaluate(" is empty([1]) ")).must_equal false
        _(evaluate(" is empty([1,2,3]) ")).must_equal false
        _(evaluate(" is empty(list: [1]) ")).must_equal false
      end
    end

    describe "A partition() function" do
      it "return list partitioned by _" do
        _(evaluate(" partition([1,2,3,4,5], 2) ")).must_equal [[1, 2], [3, 4], [5]]
        _(evaluate(" partition(list: [1,2,3,4,5], size: 2) ")).must_equal [[1, 2], [3, 4], [5]]

        _(evaluate(" partition([], 2) ")).must_equal []
        _(evaluate(" partition([1], 2) ")).must_equal [[1]]
      end

      it "return null if the size is invalid" do
        _(evaluate(" partition([1,2], 0) ")).must_be_nil

        _(evaluate(" partition([1,2], -1) ")).must_be_nil
      end
    end
  end
end
