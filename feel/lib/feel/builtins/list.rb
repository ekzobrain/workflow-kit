# frozen_string_literal: true

module FEEL
  module Builtins
    LIST = {
      "list contains": ->(list, match) {
        return if list.nil?
        return false if match.nil?
        list.include?(match)
      },
      "count": ->(list) {
        return if list.nil?
        return 0 if list.empty?
        list.length
      },
      "min": ->(list) {
        return if list.nil?
        list.min
      },
      "max": ->(list) {
        return if list.nil?
        list.max
      },
      "sum": ->(list) {
        return if list.nil?
        list.sum
      },
      "product": ->(list) {
        return if list.nil?
        list.inject(:*)
      },
      "mean": ->(list) {
        return if list.nil?
        list.sum / list.length
      },
      "median": ->(list) {
        return if list.nil?
        list.sort[list.length / 2]
      },
      "stddev": ->(list) {
        return if list.nil?
        mean = list.sum / list.length.to_f
        Math.sqrt(list.map { |n| (n - mean)**2 }.sum / list.length)
      },
      "mode": ->(list) {
        return if list.nil?
        list.group_by(&:itself).values.max_by(&:size).first
      },
      "all": ->(list) {
        return if list.nil?
        list.all?
      },
      "any": ->(list) {
        return if list.nil?
        list.any?
      },
      "sublist": ->(list, start, length) {
        return if list.nil? || start.nil?
        return [] if length.nil?
        list[start - 1, length]
      },
      "append": ->(list, item) {
        return if list.nil?
        list + [item]
      },
      "concatenate": ->(list1, list2) {
        return [nil, nil] if list1.nil? && list2.nil?
        return [nil] + list2 if list1.nil?
        return list1 + [nil] if list2.nil?
        Array.wrap(list1) + Array.wrap(list2)
      },
      "insert before": ->(list, position, item) {
        return if list.nil? || position.nil?
        list.insert(position - 1, item)
      },
      "remove": ->(list, position) {
        return if list.nil? || position.nil?
        list.delete_at(position - 1); list
      },
      "reverse": ->(list) {
        return if list.nil?
        list.reverse
      },
      "index of": ->(list, match) {
        return if list.nil?
        list.each_index.select { |index| list[index] == match }.map { |index| index + 1 }
      },
      "union": ->(list1, list2) {
        return if list1.nil? || list2.nil?
        list1 | list2
      },
      "distinct values": ->(list) {
        return if list.nil?
        list.uniq
      },
      "duplicate values": ->(list) {
        return if list.nil?
        list.select { |e| list.count(e) > 1 }.uniq
      },
      "flatten": ->(list) {
        return if list.nil?
        list.flatten
      },
      "sort": ->(list, precedes = nil) {
        return if list.nil?
        return list.sort unless precedes
        list.sort { |a, b| precedes.call(a, b) == true ? -1 : (precedes.call(b, a) == true ? 1 : 0) }
      },
      "string join": ->(list, separator) {
        return if list.nil?
        list.join(separator)
      },
    }.freeze
  end
end
