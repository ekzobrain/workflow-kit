# frozen_string_literal: true

module FEEL
  module Builtins
    CONTEXT = {
      "get value": ->(context, name) {
        return if context.nil? || name.nil?
        context[name]
      },
      "context put": ->(context, name, value) {
        return if context.nil? || name.nil?
        context[name] = value; context
      },
      "context merge": ->(context1, context2) {
        return if context1.nil? || context2.nil?
        context1.merge(context2)
      },
      "get entries": ->(context) {
        return if context.nil?
        context.entries
      },
    }.freeze
  end
end
