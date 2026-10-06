# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinFunctionsTest
module FEEL
  describe "built-in functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A built-in function" do
      it "return null if arguments doesn't match" do
        skip "Needs number() (conversion built-ins) to return null for non-string arguments"
        _(evaluate("date(true)")).must_be_nil

        _(evaluate("number(false)")).must_be_nil
      end
    end

    describe "A not() function" do
      it "negate Boolean" do
        _(evaluate("not(true)")).must_equal false

        _(evaluate("not(false)")).must_equal true
      end
    end

    describe "A is defined() function" do
      it "return true if the value is present" do
        _(evaluate("is defined(1)")).must_equal true

        _(evaluate("is defined(true)")).must_equal true

        _(evaluate("is defined([])")).must_equal true

        _(evaluate("is defined({})")).must_equal true

        _(evaluate(' is defined( {"a":1}.a ) ')).must_equal true
      end

      it "return false if the value is null" do
        _(evaluate("is defined(null)")).must_equal false
      end

      it "return false if a variable doesn't exist" do
        _(evaluate("is defined(a)")).must_equal false

        _(evaluate("is defined(a.b)")).must_equal false
      end

      it "return false if a context entry doesn't exist" do
        _(evaluate("is defined({}.a)")).must_equal false

        _(evaluate("is defined({}.a.b)")).must_equal false
      end
    end

    describe "A get or else(value: Any, default: Any) function" do
      it "return the value if not null" do
        _(evaluate("get or else(3, 1)")).must_equal 3

        _(evaluate('get or else("value", "default")')).must_equal "value"

        _(evaluate("get or else(value:3, default:1)")).must_equal 3
      end

      it "return the default param if value is null" do
        _(evaluate("get or else(null, 1)")).must_equal 1

        _(evaluate('get or else(null, "default")')).must_equal "default"

        _(evaluate("get or else(value:null, default:1)")).must_equal 1
      end

      it "return null if both value and default params are null" do
        _(evaluate("get or else(null, null)")).must_be_nil

        _(evaluate("get or else(value:null, default:null)")).must_be_nil
      end
    end

    describe "A assert(value: Any, condition: Any) function" do
      it "return the value if the condition evaluated to true" do
        _(evaluate("assert(x, x > 3)", x: 4)).must_equal 4

        _(evaluate("assert(x, x != null)", x: "value")).must_equal "value"

        _(evaluate("assert(x, x = 3)", x: 3)).must_equal 3

        _(evaluate("assert(value: x, condition: x = 3)", x: 3)).must_equal 3
      end

      it "fail the evaluation if the condition is evaluated to false" do
        _(evaluate("assert(x, x > 5)", x: 4)).must_be_nil

        _(evaluate("assert(x, x != null)")).must_be_nil

        _(evaluate("assert(x, x > 5)", x: nil)).must_be_nil

        _(evaluate("assert(x, x = 5)", x: 4)).must_be_nil

        _(evaluate("list contains(assert(my_list, my_list != null), 2)")).must_be_nil
      end
    end

    describe "A assert(value: Any, condition: Any, cause: String) function" do
      it "return the value if the condition evaluated to true" do
        _(evaluate('assert(x, x > 3, "The condition is not true")', x: 4)).must_equal 4

        _(evaluate('assert(x, x != null, "The condition is not true")', x: "value")).must_equal "value"

        _(evaluate('assert(x, x = 3, "The condition is not true")', x: 3)).must_equal 3

        _(evaluate('assert(value: x, condition: x = 3, cause: "The condition is not true")', x: 3)).must_equal 3
      end

      it "fail the evaluation with custom message if the condition is evaluated to false" do
        _(evaluate('assert(x, x > 5, "The condition is not true")', x: 4)).must_be_nil

        _(evaluate('assert(x, x != null, "The condition is not true")')).must_be_nil

        _(evaluate('assert(x, x > 5, "The condition is not true")', x: nil)).must_be_nil

        _(evaluate('assert(x, x = 5, "The condition is not true")', x: 4)).must_be_nil

        _(evaluate('list contains(assert(my_list, my_list != null, "The condition is not true"), 2)')).must_be_nil
      end
    end
  end
end
