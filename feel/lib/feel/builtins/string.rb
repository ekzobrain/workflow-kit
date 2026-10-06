# frozen_string_literal: true

module FEEL
  module Builtins
    STRING = {
      "substring": ->(string, start, length) {
        return if string.nil? || start.nil?
        return "" if length.nil?
        string[start - 1, length]
      },
      "substring before": ->(string, match) {
        return if string.nil? || match.nil?
        string.split(match).first
      },
      "substring after": ->(string, match) {
        return if string.nil? || match.nil?
        string.split(match).last
      },
      "string length": ->(string) {
        return if string.nil?
        string.length
      },
      "upper case": ->(string) {
        return if string.nil?
        string.upcase
      },
      "lower case": -> (string) {
        return if string.nil?
        string.downcase
      },
      "contains": ->(string, match) {
        return if string.nil? || match.nil?
        string.include?(match)
      },
      "starts with": ->(string, match) {
        return if string.nil? || match.nil?
        string.start_with?(match)
      },
      "ends with": ->(string, match) {
        return if string.nil? || match.nil?
        string.end_with?(match)
      },
      "matches": ->(string, match) {
        return if string.nil? || match.nil?
        string.match?(match)
      },
      "replace": ->(string, match, replacement) {
        return if string.nil? || match.nil? || replacement.nil?
        string.gsub(match, replacement)
      },
      "split": ->(string, match) {
        return if string.nil? || match.nil?
        string.split(match)
      },
      "strip": -> (string) {
        return if string.nil?
        string.strip
      },
      "extract": -> (string, pattern) {
        return if string.nil? || pattern.nil?
        string.match(pattern).captures
      },
    }.freeze
  end
end
