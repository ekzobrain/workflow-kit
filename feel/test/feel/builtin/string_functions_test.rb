# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinStringFunctionsTest
module FEEL
  describe "built-in string functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A substring() function" do
      it "return string with _ characters" do
        _(evaluate(' substring("foobar",3) ')).must_equal "obar"
      end

      it "return string with _ characters starting at _" do
        _(evaluate(' substring("foobar",3,3) ')).must_equal "oba"
      end

      it "return string with _ characters starting at negative _" do
        _(evaluate(' substring("foobar",-2,1) ')).must_equal "a"
      end

      it "be invoked with named parameters" do
        _(evaluate(' substring(string: "foobar", start position:3) ')).must_equal "obar"
      end

      it "return string with remaining characters if the length is greater than the string" do
        _(evaluate(' substring("abc", 1, 4) ')).must_equal "abc"
        _(evaluate(' substring("abc", 2, 4) ')).must_equal "bc"
        _(evaluate(' substring("abc", -1, 4) ')).must_equal "c"
        _(evaluate(' substring("abc", 4, 4) ')).must_equal ""
      end
    end

    describe "A string length() function" do
      it "return the length of a String" do
        _(evaluate(' string length("foo") ')).must_equal 3
      end
    end

    describe "A upper case() function" do
      it "return uppercased String" do
        _(evaluate(' upper case("aBc4") ')).must_equal "ABC4"
      end
    end

    describe "A lower case() function" do
      it "return lowercased String" do
        _(evaluate(' lower case("aBc4") ')).must_equal "abc4"
      end
    end

    describe "A substring before() function" do
      it "return substring before match" do
        _(evaluate(' substring before("foobar", "bar") ')).must_equal "foo"

        _(evaluate(' substring before("foobar", "xyz") ')).must_equal ""
      end
    end

    describe "A substring after() function" do
      it "return substring after match" do
        _(evaluate(' substring after("foobar", "ob") ')).must_equal "ar"

        _(evaluate(' substring after("", "a") ')).must_equal ""

        _(evaluate(' substring after("foo", "") ')).must_equal "foo"
      end
    end

    describe "A replace() function" do
      it "replace a String" do
        _(evaluate(' replace("abcd", "(ab)|(a)", "[1=$1][2=$2]") ')).must_equal "[1=ab][2=]cd"
      end

      it "replace a String with regex pattern" do
        skip "Needs string literal escapes (any character after a backslash) in feel.treetop / StringLiteral (nodes.rb)"
        _(evaluate(' replace("0123456789", "(\d{3})(\d{3})(\d{4})", "($1) $2-$3") ')).must_equal "(012) 345-6789"
      end

      it "return null if the pattern is invalid" do
        _(evaluate(' replace("abc", "([a-z)", "$1") ')).must_be_nil
      end
    end

    describe "A contains() function" do
      it "return if contains the match" do
        _(evaluate(' contains("foobar", "ob") ')).must_equal true

        _(evaluate(' contains("foobar", "of") ')).must_equal false
      end
    end

    describe "A starts with() function" do
      it "return if starts with match" do
        _(evaluate(' starts with("foobar", "fo") ')).must_equal true

        _(evaluate(' starts with("foobar", "ba") ')).must_equal false
      end
    end

    describe "A ends with() function" do
      it "return if ends with match" do
        _(evaluate(' ends with("foobar", "r") ')).must_equal true

        _(evaluate(' ends with("foobar", "o") ')).must_equal false
      end
    end

    describe "A matches() function" do
      it "return if String matches a pattern" do
        _(evaluate(' matches("foobar", "^fo*b") ')).must_equal true

        _(evaluate(' matches("foobar", "^fo*z") ')).must_equal false
      end

      it "return null if the pattern is invalid" do
        _(evaluate(' matches("abc", "[a-z") ')).must_be_nil
      end
    end

    describe "A split() function" do
      it "return a list of substrings" do
        skip "Needs string literal escapes (any character after a backslash) in feel.treetop / StringLiteral (nodes.rb)"
        _(evaluate(' split("John Doe", "\s") ')).must_equal ["John", "Doe"]

        _(evaluate(' split("a;b;c;;", ";") ')).must_equal ["a", "b", "c", "", ""]
      end
    end

    describe "An extract() function" do
      it "return a list of strings matching a pattern" do
        _(evaluate(' extract("this is foobar and folbar", "fo[a-z]*") ')).must_equal ["foobar", "folbar"]

        _(evaluate(' extract("nothing", "fo[a-z]*") ')).must_equal []

        _(evaluate(' extract("This is fobbar!", "fo[a-z]*") ')).must_equal ["fobbar"]
      end

      it "return null if the pattern is invalid" do
        _(evaluate(' extract("abc", "[a-z") ')).must_be_nil
      end
    end

    describe "A trim() function" do
      it "return the eliminates leading and trailing spaces of a String" do
        _(evaluate(' trim("hello world") ')).must_equal "hello world"

        _(evaluate(' trim("hello world  ") ')).must_equal "hello world"

        _(evaluate(' trim("  hello world") ')).must_equal "hello world"

        _(evaluate(' trim("  hello world  ") ')).must_equal "hello world"

        _(evaluate(' trim(" hello   world ") ')).must_equal "hello   world"
      end
    end

    describe "A uuid() function" do
      it "return a string" do
        _(evaluate(" uuid() ")).must_be_kind_of String
      end

      it "return a string of length 36" do
        _(evaluate(" string length(uuid()) ")).must_equal 36
      end
    end

    describe "A to base64() function" do
      it "return a string encoded as base64" do
        _(evaluate(' to base64("FEEL") ')).must_equal "RkVFTA=="

        _(evaluate(' to base64(value: "Camunda") ')).must_equal "Q2FtdW5kYQ=="
      end
    end

    describe "A from base64() function" do
      it "return a string decoded from base64" do
        _(evaluate(' from base64("RkVFTA==") ')).must_equal "FEEL"

        _(evaluate(' from base64(value: "Q2FtdW5kYQ==") ')).must_equal "Camunda"
      end

      it "return null if the value is not a valid base64 string" do
        _(evaluate(' from base64("!!!") ')).must_be_nil
      end
    end

    describe "A is blank() function" do
      it "return true if the string contains only whitespace" do
        skip "Needs string literal escapes (any character after a backslash) in feel.treetop / StringLiteral (nodes.rb)"
        _(evaluate(' is blank("") ')).must_equal true

        _(evaluate(' is blank(" ") ')).must_equal true

        _(evaluate(' is blank("\t\n\r\f") ')).must_equal true

        _(evaluate(' is blank(string: "") ')).must_equal true
      end

      it "return false if the string contains only non-whitespace characters" do
        _(evaluate(' is blank("hello world") ')).must_equal false

        _(evaluate(' is blank(" hello world ") ')).must_equal false
      end
    end
  end
end
