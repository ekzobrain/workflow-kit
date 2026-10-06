# frozen_string_literal: true

module FEEL
  module Builtins
    # Built-in functions that are not part of the DMN standard: extensions of
    # Camunda (feel-scala) and `strip` (kept for compatibility, see `trim`).
    # They can be disabled with `config.camunda_extensions = false`.
    CAMUNDA_EXTENSIONS = [
      # boolean
      "is defined", "get or else", "assert",
      # string
      "extract", "trim", "uuid", "to base64", "from base64", "is blank", "strip",
      # numeric
      "random number",
      # list
      "duplicate values", "is empty", "partition",
      # context (deprecated aliases of context put / context merge)
      "put", "put all",
      # temporal
      "last day of month",
      # conversion
      "from json", "to json",
    ].freeze
  end
end
