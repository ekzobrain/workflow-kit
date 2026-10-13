# frozen_string_literal: true

require "securerandom"

module FEEL
  module Builtins
    #
    # Helpers for the string built-ins. Patterns follow the XML Schema / Java
    # regex dialect used by feel-scala and are translated to Ruby regexps.
    #
    module StringHelpers
      # Marks an optional parameter that wasn't passed (to distinguish it from null).
      ABSENT = Object.new.freeze

      # Java `\h` / `\v` (horizontal / vertical whitespace) differ from Ruby's.
      HORIZONTAL_WHITESPACE = "\\t\\p{Zs}"
      VERTICAL_WHITESPACE = "\\n\\x0B\\f\\r\\u0085\\u2028\\u2029"

      module_function

      def string?(*values)
        values.all? { |value| value.is_a?(String) }
      end

      # Returns a Regexp for a pattern and flags (the XML Schema / XPath
      # dialect), or nil if the pattern or the flags are invalid. The flags
      # are any of "s" (dot matches all), "m" (multi-line), "i" (ignore case),
      # "x" (ignore whitespace) and "q" (literal pattern).
      def regexp(pattern, flags = nil)
        return unless string?(pattern)

        flags = "" if flags.nil?
        return unless flags.is_a?(String) && flags.match?(/\A[smixq]*\z/)

        options = 0
        options |= Regexp::IGNORECASE if flags.include?("i")
        source = if flags.include?("q")
          Regexp.escape(pattern)
        else
          translate_pattern(pattern, multiline: flags.include?("m"), dot_all: flags.include?("s"),
            extended: flags.include?("x"))
        end
        Regexp.new(source, options)
      rescue RegexpError
        nil
      end

      def translate_pattern(pattern, multiline:, dot_all: false, extended: false)
        result = +""
        in_class = 0
        index = 0
        while index < pattern.length
          char = pattern[index]
          # "x": whitespace is removed, except within character classes
          if extended && in_class.zero? && char.match?(/\s/)
            index += 1
            next
          end

          if char == "\\" && index + 1 < pattern.length
            escaped = pattern[index + 1]
            index += 2
            # "x": "\ s" is "\s"
            if extended && in_class.zero? && escaped.match?(/\s/)
              index += 1 while index < pattern.length && pattern[index].match?(/\s/)
              raise RegexpError, "invalid escape" if index >= pattern.length

              escaped = pattern[index]
              index += 1
            end
            case escaped
            when "Q"
              finish = pattern.index("\\E", index) || pattern.length
              result << Regexp.escape(pattern[index...finish])
              index = finish + 2
              next
            when "h" then result << (in_class.positive? ? HORIZONTAL_WHITESPACE : "[#{HORIZONTAL_WHITESPACE}]")
            when "H" then result << "[^#{HORIZONTAL_WHITESPACE}]"
            when "v" then result << (in_class.positive? ? VERTICAL_WHITESPACE : "[#{VERTICAL_WHITESPACE}]")
            when "V" then result << "[^#{VERTICAL_WHITESPACE}]"
            when "0" then raise RegexpError, "invalid escape \\0"
            when /\d/
              # no back-references within character classes
              raise RegexpError, "invalid back-reference" if in_class.positive?

              result << char << escaped
            when "p", "P"
              finish = pattern.index("}", index) if pattern[index] == "{"
              raise RegexpError, "invalid property" unless finish

              property = pattern[(index + 1)...finish]
              property = property.gsub(/\s/, "") if extended
              # XML Schema blocks (IsBasicLatin) are Onigmo's InBasicLatin
              property = "In#{property[2..]}" if property.start_with?("Is")
              result << char << escaped << "{" << property << "}"
              index = finish + 1
            else result << char << escaped
            end
            next
          end

          if char == "-" && pattern[index + 1] == "[" && in_class.positive?
            # character class subtraction: [a-z-[aeiou]]
            result << "&&[^"
            in_class += 1
            index += 2
            next
          end

          if char == "[" then in_class += 1
          elsif char == "]" && in_class.positive? then in_class -= 1
          end

          result << if in_class.zero? && !multiline && char == "^"
            "\\A"
          elsif in_class.zero? && !multiline && char == "$"
            "\\Z"
          elsif in_class.zero? && char == "."
            dot_all ? "(?m:.)" : "[^\\n\\r]"
          else
            char
          end
          index += 1
        end
        result
      end

      # Expands a Java-style replacement string ($1, ${name}, \$) for a match.
      def expand_replacement(match, replacement)
        result = +""
        index = 0
        while index < replacement.length
          char = replacement[index]
          if char == "\\" && index + 1 < replacement.length
            result << replacement[index + 1]
            index += 2
          elsif char == "$" && replacement[index + 1] == "{"
            finish = replacement.index("}", index)
            raise ArgumentError, "invalid group reference" unless finish

            result << (match[replacement[(index + 2)...finish]] || "")
            index = finish + 1
          elsif char == "$" && replacement[index + 1]&.match?(/\d/)
            group = replacement[index + 1].to_i
            index += 2
            while index < replacement.length && replacement[index].match?(/\d/) &&
                (candidate = group * 10 + replacement[index].to_i) < match.size
              group = candidate
              index += 1
            end
            raise ArgumentError, "invalid group reference" if group >= match.size

            result << (match[group] || "")
          elsif char == "$"
            raise ArgumentError, "invalid group reference"
          else
            result << char
            index += 1
          end
        end
        result
      end

      # Yields each match of the regexp in the string, like Java's Matcher#find.
      def each_match(string, regexp)
        return enum_for(:each_match, string, regexp) unless block_given?

        position = 0
        while position <= string.length && (match = regexp.match(string, position))
          yield match
          position = match.end(0) == match.begin(0) ? match.end(0) + 1 : match.end(0)
        end
      end

      # Splits like Java's Pattern#split(input, -1).
      def split(string, regexp)
        parts = []
        index = 0
        each_match(string, regexp) do |match|
          next if index.zero? && match.begin(0).zero? && match.end(0).zero?

          parts << string[index...match.begin(0)]
          index = match.end(0)
        end
        return [string] if index.zero? && parts.empty?

        parts << string[index..]
      end

      # Converts a 1-based (or negative, from the end) position to an index.
      def string_index(string, position)
        position.positive? ? position - 1 : string.length + position
      end
    end

    STRING = {
      "substring": ->(string, start_position, length = StringHelpers::ABSENT) {
        return unless StringHelpers.string?(string) && start_position.is_a?(Numeric)

        start_index = StringHelpers.string_index(string, start_position.to_i)
        return if start_index.negative? || start_index > string.length
        return string[start_index..] if length.equal?(StringHelpers::ABSENT)
        return unless length.is_a?(Numeric) && length >= 0

        string[start_index, length.to_i]
      },
      "substring before": ->(string, match) {
        return unless StringHelpers.string?(string, match)

        index = string.index(match)
        index&.positive? ? string[0...index] : ""
      },
      "substring after": ->(string, match) {
        return unless StringHelpers.string?(string, match)

        index = string.index(match)
        index ? string[(index + match.length)..] : ""
      },
      "string length": ->(string) {
        return unless StringHelpers.string?(string)

        string.length
      },
      "upper case": ->(string) {
        return unless StringHelpers.string?(string)

        string.upcase
      },
      "lower case": ->(string) {
        return unless StringHelpers.string?(string)

        string.downcase
      },
      "contains": ->(string, match) {
        return unless StringHelpers.string?(string, match)

        string.include?(match)
      },
      "starts with": ->(string, match) {
        return unless StringHelpers.string?(string, match)

        string.start_with?(match)
      },
      "ends with": ->(string, match) {
        return unless StringHelpers.string?(string, match)

        string.end_with?(match)
      },
      "matches": ->(input, pattern, flags = nil) {
        return unless StringHelpers.string?(input)

        StringHelpers.regexp(pattern, flags)&.match?(input)
      },
      "replace": ->(input, pattern, replacement, flags = nil) do
        return unless StringHelpers.string?(input, replacement)

        regexp = StringHelpers.regexp(pattern, flags)
        return unless regexp

        result = +""
        index = 0
        StringHelpers.each_match(input, regexp) do |match|
          result << input[index...match.begin(0)] << StringHelpers.expand_replacement(match, replacement)
          index = match.end(0)
        end
        result << input[index..]
      rescue ArgumentError, IndexError
        nil
      end,
      "split": ->(string, delimiter) {
        return unless StringHelpers.string?(string)

        regexp = StringHelpers.regexp(delimiter)
        regexp && StringHelpers.split(string, regexp)
      },
      "extract": ->(input, pattern) {
        return unless StringHelpers.string?(input)

        regexp = StringHelpers.regexp(pattern)
        regexp && StringHelpers.each_match(input, regexp).map { |match| match[0] }
      },
      "trim": ->(string) {
        return unless StringHelpers.string?(string)

        # Like Java's String#trim: removes leading and trailing characters <= U+0020.
        string.sub(/\A[\u0000- ]+/, "").sub(/[\u0000- ]+\z/, "")
      },
      # Not a standard FEEL function; kept for backward compatibility.
      "strip": ->(string) {
        return unless StringHelpers.string?(string)

        string.strip
      },
      "uuid": -> {
        SecureRandom.respond_to?(:uuid_v7) ? SecureRandom.uuid_v7 : SecureRandom.uuid
      },
      "to base64": ->(value) {
        return unless StringHelpers.string?(value)

        [value.encode("UTF-8")].pack("m0")
      },
      "from base64": ->(value) do
        return unless StringHelpers.string?(value)

        padded = value.length % 4 == 0 ? value : value + "=" * (4 - value.length % 4)
        padded.unpack1("m0").force_encoding("UTF-8").scrub
      rescue ArgumentError
        nil
      end,
      "is blank": ->(string) {
        return unless StringHelpers.string?(string)

        string.match?(/\A[[:space:]]*\z/)
      },
    }.freeze
  end
end
