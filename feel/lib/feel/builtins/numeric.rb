# frozen_string_literal: true

module FEEL
  module Builtins
    NUMERIC = {
      "decimal": ->(n, scale) {
        return if n.nil? || scale.nil?
        n.round(scale)
      },
      "floor": ->(n) {
        return if n.nil?
        n.floor
      },
      "ceiling": ->(n) {
        return if n.nil?
        n.ceil
      },
      "round up": ->(n) {
        return if n.nil?
        n.ceil
      },
      "round down": ->(n) {
        return if n.nil?
        n.floor
      },
      "abs": ->(n) {
        return if n.nil?
        n.abs
      },
      "modulo": ->(n, divisor) {
        return if n.nil? || divisor.nil?
        n % divisor
      },
      "sqrt": ->(n) {
        return if n.nil?
        Math.sqrt(n)
      },
      "log": ->(n) {
        return if n.nil?
        Math.log(n)
      },
      "exp": ->(n) {
        return if n.nil?
        Math.exp(n)
      },
      "odd": ->(n) {
        return if n.nil?
        n.odd?
      },
      "even": ->(n) {
        return if n.nil?
        n.even?
      },
      "random number": ->(n) {
        return if n.nil?
        rand(n)
      },
    }.freeze
  end
end
