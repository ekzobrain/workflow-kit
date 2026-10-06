# frozen_string_literal: true

require_relative "feel/version"

require "bigdecimal"
require "date"
require "json"
require "set"
require "time"
require "tzinfo"

# Special handling because this gem causes lots of Ruby warnings about
# formatting.
verbose, $VERBOSE = $VERBOSE, nil
require "treetop"
$VERBOSE = verbose

require "feel/errors"
require "feel/configuration"
require "feel/expression_cache"
require "feel/scope"
require "feel/function"
require "feel/duration"
require "feel/values"
require "feel/range"
require "feel/temporal"
require "feel/nodes"
require "feel/compiler"
require "feel/ast"
require "feel/parser"

Dir[File.join(__dir__, "feel/builtins/*.rb")].sort.each { |file| require file }
require "feel/literal_expression"
require "feel/unary_tests"
require "feel/serialization"

module FEEL
  # Evaluates an expression with the given variables. The parsed expression is
  # cached (see FEEL.compile), so evaluating the same text again is cheap.
  def self.evaluate(expression_text, variables: {})
    compile(expression_text).evaluate(variables)
  end

  # Evaluates unary tests against an input value. The parsed tests are cached
  # (see FEEL.compile_test).
  def self.test(input, unary_tests_text, variables: {})
    compile_test(unary_tests_text).test(input, variables)
  end

  # Parses an expression once and returns a reusable FEEL::LiteralExpression
  # that can be evaluated many times with different variables:
  #
  #   expression = FEEL.compile("a + b")
  #   expression.evaluate(a: 1, b: 2) # => 3
  #   expression.evaluate(a: 5, b: 6) # => 11
  #
  # Compiled expressions are cached by text (LRU, see
  # `config.expression_cache_size`) and are safe to share between threads.
  # Raises FEEL::SyntaxError if the expression is not valid.
  def self.compile(expression_text)
    expression = expression_cache.fetch(expression_text) do
      LiteralExpression.new(text: expression_text).tap(&:valid?)
    end
    raise SyntaxError, "Expression is not valid: #{expression_text}" unless expression.valid?

    expression
  end

  # Parses unary tests once and returns a reusable FEEL::UnaryTests, cached
  # like FEEL.compile. Raises FEEL::SyntaxError if the tests are not valid.
  def self.compile_test(unary_tests_text)
    unary_tests = unary_tests_cache.fetch(unary_tests_text) do
      UnaryTests.new(text: unary_tests_text).tap(&:valid?)
    end
    raise SyntaxError, "Unary tests are not valid: #{unary_tests_text}" unless unary_tests.valid?

    unary_tests
  end

  # Returns the abstract syntax tree of an expression as plain Hashes (see
  # FEEL::AST and the README for the node types):
  #
  #   FEEL.parse("age >= 18")
  #   # => { type: "comparison", operator: ">=",
  #   #      left: { type: "name", path: ["age"] }, right: { type: "number", value: 18 } }
  #
  # Raises FEEL::SyntaxError if the expression is not valid.
  def self.parse(expression_text)
    compile(expression_text).tree.to_ast
  end

  # Returns the abstract syntax tree of unary tests, e.g. `< 10, [20..30]`,
  # `not("A")` or `-`. Raises FEEL::SyntaxError if the tests are not valid.
  def self.parse_test(unary_tests_text)
    compile_test(unary_tests_text).tree.to_ast
  end

  def self.expression_cache
    @expression_cache ||= ExpressionCache.new(config.expression_cache_size)
  end

  def self.unary_tests_cache
    @unary_tests_cache ||= ExpressionCache.new(config.expression_cache_size)
  end

  def self.clear_expression_cache
    expression_cache.clear
    unary_tests_cache.clear
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
  end
end
