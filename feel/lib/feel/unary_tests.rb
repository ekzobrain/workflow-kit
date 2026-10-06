# frozen_string_literal: true

module FEEL
  class UnaryTests < LiteralExpression
    attr_reader :id, :text

    def self.from_json(json)
      UnaryTests.new(id: json[:id], text: json[:text])
    end

    def tree
      @tree ||= Parser.parse_test(text)
    end

    def valid?
      return true if text.nil? || text == "-"
      return @valid if defined?(@valid)

      @valid = begin
        !tree.nil?
      rescue SyntaxError
        false
      end
    end

    def test(input, variables = {})
      return true if text.nil? || text == "-"
      tree.matches(input, RootScope.build(variables)) == true
    end
  end
end
