# frozen_string_literal: true

module FEEL
  module Builtins
    CONVERSION = {
      "string": ->(from) {
        return if from.nil?
        from.to_s
      },
      "number": ->(from) {
        return if from.nil?
        from.include?(".") ? from.to_f : from.to_i
      },
    }.freeze
  end
end
