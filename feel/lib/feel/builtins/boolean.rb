# frozen_string_literal: true

module FEEL
  module Builtins
    BOOLEAN = {
      "not": ->(value) {
        if value == true || value == false
          !value
        end
      },
      "is defined": ->(value) {
        return if value.nil?
        !value.nil?
      },
      "get or else": ->(value, default) {
        value.nil? ? default : value
      },
    }.freeze
  end
end
