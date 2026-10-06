# frozen_string_literal: true

require "bigdecimal"

module FEEL
  module Builtins
    #
    # Helpers shared by the list built-in functions. Built-ins never mutate
    # their input lists and return nil for invalid arguments.
    #
    module ListSupport
      extend Values

      # Marks an optional parameter that wasn't passed (to tell it apart from
      # an explicit null argument).
      NOT_GIVEN = Object.new.freeze

      # Precision used for decimal division (like Java's MathContext.DECIMAL128).
      DIVISION_PRECISION = 34

      module_function

      # Arguments of a varargs function: either the items themselves or a
      # single list argument, e.g. `min(1, 2, 3)` and `min([1, 2, 3])`.
      # Returns nil if no argument was passed.
      def varargs(args)
        return if args.empty?
        return args.first if args.length == 1 && args.first.is_a?(Array)

        args
      end

      def numbers?(list)
        list.is_a?(Array) && list.all? { |item| item.is_a?(Numeric) }
      end

      def to_decimal(number)
        case number
        when BigDecimal then number
        when Float then BigDecimal(number.to_s)
        else BigDecimal(number)
        end
      end

      # Converts a decimal result back to the representation of the inputs:
      # BigDecimal if any input was a BigDecimal, otherwise Integer or Float.
      def to_number(decimal, inputs)
        return decimal if inputs.any? { |item| item.is_a?(BigDecimal) }

        decimal.frac.zero? ? decimal.to_i : decimal.to_f
      end

      # Applies the block to the list items as BigDecimals. Returns nil unless
      # the list is non-empty and contains only numbers.
      def with_numbers(list)
        return unless numbers?(list) && !list.empty?

        to_number(yield(list.map { |item| to_decimal(item) }), list)
      end

      def sum(decimals)
        decimals.reduce(BigDecimal(0), :+)
      end

      def divide(decimal, divisor)
        decimal.div(divisor, DIVISION_PRECISION)
      end

      # Like Val#isComparable in feel-scala: all items are comparable values
      # of the same type.
      def comparable?(list)
        return false unless list.is_a?(Array) && !list.empty?

        kind = type_kind(list.first)
        return false unless %i[number string duration temporal].include?(kind)
        return list.all? { |item| item.is_a?(Numeric) } if kind == :number
        return list.all? { |item| item.is_a?(ActiveSupport::Duration) } if kind == :duration

        list.all? { |item| item.class == list.first.class }
      end

      # The position of a 1-based (or negative, counted from the end) list
      # position as 0-based index.
      def list_index(list, position)
        position > 0 ? position - 1 : list.length + position
      end

      def position?(value)
        value.is_a?(Numeric) && value.to_i != 0
      end

      # Ruby equivalent of Scala's Seq#slice(from, until).
      def slice(list, from, to)
        from = [from, 0].max
        to = [to, list.length].min
        to <= from ? [] : list[from...to]
      end

      def includes?(list, value)
        list.any? { |item| feel_equal(item, value) }
      end

      # Removes duplicates using FEEL equality, preserving the order.
      def distinct(list)
        return list.uniq if list.all? { |item| item.nil? || item.is_a?(String) || item.is_a?(Integer) || item == true || item == false }

        list.each_with_object([]) do |item, result|
          result << item unless includes?(result, item)
        end
      end

      def flatten(list)
        list.flat_map { |item| item.is_a?(Array) ? flatten(item) : [item] }
      end

      # Three-valued AND of the items (feel-scala semantics).
      def all(items)
        items.reduce(true) do |result, item|
          if result == false then false
          elsif result == true && (item == true || item == false) then item
          elsif result.nil? && item == false then false
          end
        end
      end

      # Three-valued OR of the items (feel-scala semantics).
      def any(items)
        items.reduce(false) do |result, item|
          if result == true then true
          elsif result == false && (item == true || item == false) then item
          elsif result.nil? && item == true then true
          end
        end
      end

      # Stable merge sort using the given `precedes` function. Raises
      # ArgumentError if the function doesn't return a boolean.
      def sort_with(list, precedes)
        return list.dup if list.length <= 1

        middle = list.length / 2
        left = sort_with(list[0...middle], precedes)
        right = sort_with(list[middle..], precedes)
        result = []
        until left.empty? || right.empty?
          # take from right only if it strictly precedes the left item (stable)
          result << (precedes?(precedes, right.first, left.first) ? right.shift : left.shift)
        end
        result + left + right
      end

      def precedes?(precedes, x, y)
        result = precedes.call(x, y)
        raise ArgumentError, "expected boolean but found '#{result.inspect}'" unless result == true || result == false

        result
      end

      def join(list, delimiter: "", prefix: "", suffix: "")
        return unless list.is_a?(Array) && list.all? { |item| item.nil? || item.is_a?(String) }

        prefix + list.compact.join(delimiter) + suffix
      end
    end

    LIST = {
      "list contains": ->(list, element) {
        return unless list.is_a?(Array)
        ListSupport.includes?(list, element)
      },
      "count": ->(list) {
        return unless list.is_a?(Array)
        list.length
      },
      "min": ->(*list) {
        list = ListSupport.varargs(list)
        ListSupport.comparable?(list) ? list.min : nil
      },
      "max": ->(*list) {
        list = ListSupport.varargs(list)
        ListSupport.comparable?(list) ? list.max : nil
      },
      "sum": ->(*list) {
        ListSupport.with_numbers(ListSupport.varargs(list)) { |numbers| ListSupport.sum(numbers) }
      },
      "product": ->(*list) {
        ListSupport.with_numbers(ListSupport.varargs(list)) { |numbers| numbers.reduce(:*) }
      },
      "mean": ->(*list) {
        ListSupport.with_numbers(ListSupport.varargs(list)) do |numbers|
          ListSupport.divide(ListSupport.sum(numbers), numbers.length)
        end
      },
      "median": ->(*list) {
        ListSupport.with_numbers(ListSupport.varargs(list)) do |numbers|
          sorted = numbers.sort
          middle = sorted.length / 2
          sorted.length.odd? ? sorted[middle] : ListSupport.divide(sorted[middle - 1] + sorted[middle], 2)
        end
      },
      "stddev": ->(*list) {
        list = ListSupport.varargs(list)
        return unless ListSupport.numbers?(list) && list.length > 1
        numbers = list.map { |item| ListSupport.to_decimal(item) }
        mean = ListSupport.divide(ListSupport.sum(numbers), numbers.length)
        deviation = ListSupport.sum(numbers.map { |n| (n - mean)**2 })
        stddev = Math.sqrt(ListSupport.divide(deviation, numbers.length - 1).to_f)
        list.any? { |item| item.is_a?(BigDecimal) } ? BigDecimal(stddev.to_s) : stddev
      },
      "mode": ->(*list) {
        list = ListSupport.varargs(list)
        return [] if list == []
        return unless ListSupport.numbers?(list)
        counts = list.group_by { |item| ListSupport.to_decimal(item) }.transform_values(&:length)
        max_count = counts.values.max
        counts.select { |_n, count| count == max_count }.keys.sort.map { |n| ListSupport.to_number(n, list) }
      },
      "and": ->(*list) {
        list = ListSupport.varargs(list)
        list && ListSupport.all(list)
      },
      "all": ->(*list) {
        list = ListSupport.varargs(list)
        list && ListSupport.all(list)
      },
      "or": ->(*list) {
        list = ListSupport.varargs(list)
        list && ListSupport.any(list)
      },
      "any": ->(*list) {
        list = ListSupport.varargs(list)
        list && ListSupport.any(list)
      },
      "sublist": ->(list, start, length = ListSupport::NOT_GIVEN) {
        return unless list.is_a?(Array) && ListSupport.position?(start)
        from = ListSupport.list_index(list, start.to_i)
        if length.equal?(ListSupport::NOT_GIVEN)
          ListSupport.slice(list, from, list.length)
        else
          return unless length.is_a?(Numeric)
          ListSupport.slice(list, from, from + length.to_i)
        end
      },
      "append": ->(list, *items) {
        return unless list.is_a?(Array) && !items.empty?
        list + items
      },
      "concatenate": ->(*lists) {
        lists = ListSupport.varargs(lists)
        return if lists.nil?
        lists.flat_map { |list| list.is_a?(Array) ? list : [list] }
      },
      "insert before": ->(list, position, newItem) {
        return unless list.is_a?(Array) && ListSupport.position?(position)
        index = [ListSupport.list_index(list, position.to_i), 0].max
        list.take(index) + [newItem] + list.drop(index)
      },
      "remove": ->(list, position) {
        return unless list.is_a?(Array) && ListSupport.position?(position)
        position = position.to_i
        list.take([ListSupport.list_index(list, position), 0].max) +
          list.drop([ListSupport.list_index(list, position + 1), 0].max)
      },
      "reverse": ->(list) {
        return unless list.is_a?(Array)
        list.reverse
      },
      "index of": ->(list, match) {
        return unless list.is_a?(Array)
        list.each_index.select { |index| ListSupport.feel_equal(list[index], match) }.map { |index| index + 1 }
      },
      "union": ->(*lists) {
        lists = ListSupport.varargs(lists)
        return if lists.nil?
        ListSupport.distinct(lists.flat_map { |list| list.is_a?(Array) ? list : [list] })
      },
      "distinct values": ->(list) {
        return unless list.is_a?(Array)
        ListSupport.distinct(list)
      },
      "duplicate values": ->(list) {
        return unless list.is_a?(Array)
        ListSupport.distinct(list).select do |value|
          list.count { |item| ListSupport.feel_equal(item, value) } > 1
        end
      },
      "flatten": ->(list) {
        return unless list.is_a?(Array)
        ListSupport.flatten(list)
      },
      "sort": ->(list, precedes = nil) {
        return unless list.is_a?(Array)
        if precedes.nil?
          return list.dup if list.empty?
          return unless ListSupport.comparable?(list)
          return list.sort
        end
        return unless precedes.respond_to?(:call)
        return if precedes.is_a?(Function) && precedes.arity != 2
        begin
          ListSupport.sort_with(list, precedes)
        rescue ArgumentError
          nil
        end
      },
      "string join": ->(list, delimiter = nil, prefix = ListSupport::NOT_GIVEN, suffix = ListSupport::NOT_GIVEN) {
        return unless delimiter.nil? || delimiter.is_a?(String)
        given = [prefix, suffix].reject { |value| value.equal?(ListSupport::NOT_GIVEN) }
        return unless given.empty? || given.length == 2
        prefix, suffix = given
        if prefix.nil? && suffix.nil?
          ListSupport.join(list, delimiter: delimiter.to_s)
        elsif prefix.is_a?(String) && suffix.is_a?(String)
          ListSupport.join(list, delimiter: delimiter.to_s, prefix: prefix, suffix: suffix)
        end
      },
      "is empty": ->(list) {
        return unless list.is_a?(Array)
        list.empty?
      },
      "partition": ->(list, size) {
        return unless list.is_a?(Array) && size.is_a?(Numeric) && size.to_i > 0
        list.each_slice(size.to_i).to_a
      },
    }.freeze
  end
end
