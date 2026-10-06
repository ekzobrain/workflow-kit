# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterStringExpressionTest
module FEEL
  describe "string expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A string" do
      it "concatenates to another String" do
        _(evaluate(' "a" + "b" ')).must_equal "ab"
      end

      it "compare with '='" do
        _(evaluate(' "a" = "a" ')).must_equal true
        _(evaluate(' "a" = "b" ')).must_equal false
      end

      it "compare with '!='" do
        _(evaluate(' "a" != "a" ')).must_equal false
        _(evaluate(' "a" != "b" ')).must_equal true
      end

      it "compare with '<'" do
        _(evaluate(' "a" < "b" ')).must_equal true
        _(evaluate(' "b" < "a" ')).must_equal false
      end

      it "compare with '<='" do
        _(evaluate(' "a" <= "a" ')).must_equal true
        _(evaluate(' "b" <= "a" ')).must_equal false
      end

      it "compare with '>'" do
        _(evaluate(' "b" > "a" ')).must_equal true
        _(evaluate(' "a" > "b" ')).must_equal false
      end

      it "compare with '>='" do
        _(evaluate(' "b" >= "b" ')).must_equal true
        _(evaluate(' "a" >= "b" ')).must_equal false
      end

      it "compare with null" do
        _(evaluate(' "a" = null ')).must_equal false
        _(evaluate(' null = "a" ')).must_equal false
        _(evaluate(' "a" != null ')).must_equal true
      end

      # [character in the FEEL source, expected character, display name]
      escape_sequences = [
        ["\n", "\n", "new line"],
        ["\r", "\r", "carriage return"],
        ["\t", "\t", "tab"],
        ["\b", "\b", "backspace"],
        ["\f", "\f", "form feed"],
        ["'", "'", "single quote"],
        ["\\\"", "\"", "double quote"],
        ["\\\\", "\\", "backslash"],
      ].freeze

      it "contains an escape sequence" do
        escape_sequences.each do |character, expected, _|
          expected_string = "a #{expected} b"

          _(evaluate(" \"a #{character} b\" ")).must_equal expected_string
          _(evaluate("char", char: expected_string)).must_equal expected_string
        end
      end

      unicode_characters = [
        ["⚝", "\\u269D"],
        ["\\U101EF", "\\U101EF"],
      ].freeze

      it "contains unicode characters" do
        skip "Needs string literal escapes (any character after a backslash) in feel.treetop / StringLiteral (nodes.rb)"
        unicode_characters.each do |character, _|
          _(evaluate(" \"a #{character} b\" ")).must_equal "a #{character} b"
        end
      end

      regex_characters = [
        ["\\s", "\\s"],
        ["\\S", "\\S"],
        ["\\d", "\\d"],
        ["\\w", "\\w"],
        ["\\R", "\\R"],
        ["\\h", "\\h"],
        ["\\v", "\\v"],
        ["\\\n", "\\n"],
        ["\\\r", "\\r"],
      ].freeze

      it "contains a regex character" do
        skip "Needs string literal escapes (any character after a backslash) in feel.treetop / StringLiteral (nodes.rb)"
        regex_characters.each do |character, _|
          expected_string = "a #{character} b"

          _(evaluate(" \"a #{character} b\" ")).must_equal expected_string
          _(evaluate("char", char: expected_string)).must_equal expected_string
        end
      end
    end
  end
end
