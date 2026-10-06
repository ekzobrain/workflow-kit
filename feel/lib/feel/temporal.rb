# frozen_string_literal: true

module FEEL
  #
  # Parsing and helpers for temporal values (date, time, date and time, duration).
  #
  module Temporal
    module_function

    # Parses the string of an `@"..."` literal.
    def parse_literal(value)
      return nil if value.nil?

      case value
      when /\A-?P/
        ActiveSupport::Duration.parse(value)
      when /\A\d{4}-\d{2}-\d{2}T/
        DateTime.parse(value)
      when /\A\d{4}-\d{2}-\d{2}\z/
        Date.parse(value)
      when /\A\d{2}:\d{2}/
        Time.parse(value)
      end
    end
  end
end
