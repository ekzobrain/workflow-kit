# frozen_string_literal: true

module FEEL
  class UnaryTests < LiteralExpression
    attr_reader :id, :text

    def self.from_json(json)
      UnaryTests.new(id: json[:id], text: json[:text])
    end

    # The parsed tree, shared with the unary tests of the same text (see
    # FEEL.unary_tests_tree_cache).
    def tree
      @tree ||= FEEL.unary_tests_tree_cache.fetch(text) { Parser.parse_test(text.nil? || text.empty? ? "-" : text) }
    end

    # Parses the unary tests and compiles them into closures now rather than on
    # the first test. Raises FEEL::SyntaxError if they are not valid.
    def compile!
      tree.compiled_test unless any_input?
      self
    end

    def valid?
      return true if any_input?
      return @valid if defined?(@valid)

      @valid = begin
        !tree.nil?
      rescue SyntaxError
        false
      end
    end

    def test(input, variables = {})
      return true if any_input?
      tree.compiled_test.call(input, RootScope.build(variables)) == true
    end

    private

    # No test (empty, or `-`): any input matches.
    def any_input?
      text.nil? || text.empty? || text == "-"
    end
  end
end
