# frozen_string_literal: true

module FEEL
  class LiteralExpression
    attr_reader :id, :text

    def self.from_json(json)
      LiteralExpression.new(id: json[:id], text: json[:text])
    end

    def initialize(id: nil, text:)
      @id = id
      @text = text&.strip
    end

    def tree
      @tree ||= FEEL::Parser.parse(text)
    end

    def valid?
      return false if text.blank?
      tree.present?
    rescue SyntaxError
      false
    end

    def evaluate(variables = {})
      tree.eval(functions.merge(variables))
    end

    def functions
      builtins = LiteralExpression.builtin_functions
      custom = (FEEL.config.functions || {})
      ActiveSupport::HashWithIndifferentAccess.new(builtins.merge(custom))
    end

    def named_functions
      return [] if text.blank?

      function_names = Set.new
      walk_tree(tree) do |node, _bound_names|
        function_names << node.function_name if node.is_a?(FEEL::FunctionInvocation)
      end
      function_names.to_a
    end

    def named_variables
      return [] if text.blank?

      qualified_names = Set.new
      walk_tree(tree) do |node, bound_names|
        next unless node.is_a?(FEEL::QualifiedName)
        next if bound_names.include?(node.head.eval)

        qualified_names << node.text_value.gsub(/\s+/, "")
      end
      qualified_names.to_a
    end

    # Walks the tree, yielding each node with the names bound by enclosing
    # for/quantified expressions, filters and function definitions.
    def walk_tree(node, bound_names = Set.new, &block)
      bound_names = bound_names | node.local_names if node.respond_to?(:local_names)
      bound_names = bound_names | node.parameter_names if node.is_a?(FEEL::FunctionDefinition)
      yield node, bound_names

      node.elements&.each { |child| walk_tree(child, bound_names, &block) }
    end

    def self.builtin_functions
      HashWithIndifferentAccess.new({
        # Conversion functions
        "string": ->(from) {
          return if from.nil?
          from.to_s
        },
        "number": ->(from) {
          return if from.nil?
          from.include?(".") ? from.to_f : from.to_i
        },
        "date": ->(from, month = nil, day = nil) {
          return if from.nil?
          return Date.new(from, month, day) if from.is_a?(Integer) && month && day
          case from
          when DateTime, Time, ActiveSupport::TimeWithZone then from.to_date
          when Date then from
          when String then Date.parse(from)
          end
        },
        "time": ->(from) {
          return if from.nil?
          case from
          when Time, ActiveSupport::TimeWithZone then from
          when DateTime then from.to_time
          when String then Time.parse(from)
          end
        },
        "date and time": ->(from, time = nil) {
          return if from.nil?
          if time
            return DateTime.new(from.year, from.month, from.day, time.hour, time.min, time.sec, time.respond_to?(:utc_offset) ? Rational(time.utc_offset, 86_400) : 0)
          end
          case from
          when DateTime, Time, ActiveSupport::TimeWithZone then from
          when Date then from.to_datetime
          when String then DateTime.parse(from)
          end
        },
        "duration": ->(from, to = nil) {
          return if from.nil?
          return from if from.is_a?(ActiveSupport::Duration)
          return (Date.parse(to.to_s) - Date.parse(from.to_s)).to_i.days if to
          ActiveSupport::Duration.parse(from)
        },
        "years and months duration": ->(from, to) {
          return if from.nil? || to.nil?
          months = (to.year * 12 + to.month) - (from.year * 12 + from.month)
          months -= 1 if months.positive? && to.day < from.day
          months += 1 if months.negative? && to.day > from.day
          ActiveSupport::Duration.build(0) + (months / 12).years + (months % 12).months
        },
        # Boolean functions
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
        # String functions
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
        # Numeric functions
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
        # List functions
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
        # Context functions
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
        # Temporal functions
        "now": ->() { Time.now },
        "today": ->() { Date.today },
        "day of week": ->(date) {
          return if date.nil?
          date.wday
        },
        "day of year": ->(date) {
          return if date.nil?
          date.yday
        },
        "week of year": ->(date) {
          return if date.nil?
          date.cweek
        },
        "month of year": ->(date) {
          return if date.nil?
          date.month
        },
      })
    end

    def as_json
      {
        id: id,
        text: text,
      }
    end
  end
end
