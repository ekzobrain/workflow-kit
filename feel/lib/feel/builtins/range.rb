# frozen_string_literal: true

module FEEL
  module Builtins
    #
    # Implementation of the range built-in functions (`before`, `after`,
    # `meets`, ...). Each relation takes two arguments, each a point (number or
    # temporal value) or a FEEL::Range, and returns true/false, or nil if the
    # arguments are not comparable or the combination is not supported.
    #
    module RangeRelations
      module_function

      def lt(left, right) = FEEL::Range.compare_values(left, right) == -1
      def gt(left, right) = FEEL::Range.compare_values(left, right) == 1
      def eq(left, right) = FEEL::Range.compare_values(left, right) == 0

      # Invokes the relation with the single group of arguments that was given
      # (positional arguments fill the first group).
      def invoke(relation, *groups)
        given = groups.reject { |group| group.all?(&:nil?) }
        return nil unless given.length == 1

        x, y = given.first
        return nil unless comparable?(x, y)

        public_send(relation, x, y)
      end

      def comparable?(x, y)
        x = x.sample if x.is_a?(FEEL::Range)
        y = y.sample if y.is_a?(FEEL::Range)
        FEEL::Range.point?(x) && FEEL::Range.point?(y) && FEEL::Range.kind(x) == FEEL::Range.kind(y)
      end

      def shape(x, y)
        [x.is_a?(FEEL::Range) ? :range : :point, y.is_a?(FEEL::Range) ? :range : :point]
      end

      def before(x, y)
        case shape(x, y)
        in [:range, :range]
          lt(x.upper_bound, y.lower_bound) ||
            ((!x.end_included || !y.start_included) && eq(x.upper_bound, y.lower_bound))
        in [:point, :range]
          lt(x, y.lower_bound) || (eq(x, y.lower_bound) && !y.start_included)
        in [:range, :point]
          lt(x.upper_bound, y) || (eq(x.upper_bound, y) && !x.end_included)
        in [:point, :point]
          lt(x, y)
        end
      end

      def after(x, y)
        case shape(x, y)
        in [:range, :range]
          gt(x.lower_bound, y.upper_bound) ||
            ((!x.start_included || !y.end_included) && eq(x.lower_bound, y.upper_bound))
        in [:point, :range]
          gt(x, y.upper_bound) || (eq(x, y.upper_bound) && !y.end_included)
        in [:range, :point]
          gt(x.lower_bound, y) || (eq(x.lower_bound, y) && !x.start_included)
        in [:point, :point]
          gt(x, y)
        end
      end

      def meets(x, y)
        return nil unless shape(x, y) == %i[range range]

        x.end_included && y.start_included && eq(x.upper_bound, y.lower_bound)
      end

      def met_by(x, y)
        return nil unless shape(x, y) == %i[range range]

        x.start_included && y.end_included && eq(x.lower_bound, y.upper_bound)
      end

      def overlaps(x, y)
        return nil unless shape(x, y) == %i[range range]

        s1, e1, s2, e2 = x.lower_bound, x.upper_bound, y.lower_bound, y.upper_bound
        (gt(e1, s2) || (eq(e1, s2) && x.end_included && y.start_included)) &&
          (lt(s1, e2) || (eq(s1, e2) && x.start_included && y.end_included))
      end

      def overlaps_before(x, y)
        return nil unless shape(x, y) == %i[range range]

        s1, e1, s2, e2 = x.lower_bound, x.upper_bound, y.lower_bound, y.upper_bound
        (lt(s1, s2) || (eq(s1, s2) && x.start_included && !y.start_included)) &&
          (gt(e1, s2) || (eq(e1, s2) && x.end_included && y.start_included)) &&
          (lt(e1, e2) || (eq(e1, e2) && (!x.end_included || y.end_included)))
      end

      def overlaps_after(x, y)
        overlaps_before(y, x)
      end

      def finishes(x, y)
        case shape(x, y)
        in [:range, :range]
          x.end_included == y.end_included && eq(x.upper_bound, y.upper_bound) &&
            (gt(x.lower_bound, y.lower_bound) ||
              (eq(x.lower_bound, y.lower_bound) && (!x.start_included || y.start_included)))
        in [:point, :range]
          y.end_included && eq(y.upper_bound, x)
        else nil
        end
      end

      def finished_by(x, y)
        case shape(x, y)
        in [:range, :range] then finishes(y, x)
        in [:range, :point] then finishes(y, x)
        else nil
        end
      end

      def includes(x, y)
        case shape(x, y)
        in [:range, :range]
          (lt(x.lower_bound, y.lower_bound) ||
            (eq(x.lower_bound, y.lower_bound) && (x.start_included || !y.start_included))) &&
            (gt(x.upper_bound, y.upper_bound) ||
              (eq(x.upper_bound, y.upper_bound) && (x.end_included || !y.end_included)))
        in [:range, :point]
          (lt(x.lower_bound, y) && gt(x.upper_bound, y)) ||
            (eq(x.lower_bound, y) && x.start_included) ||
            (eq(x.upper_bound, y) && x.end_included)
        else nil
        end
      end

      def during(x, y)
        case shape(x, y)
        in [:range, :range] then includes(y, x)
        in [:point, :range] then includes(y, x)
        else nil
        end
      end

      def starts(x, y)
        case shape(x, y)
        in [:range, :range]
          eq(x.lower_bound, y.lower_bound) && x.start_included == y.start_included &&
            (lt(x.upper_bound, y.upper_bound) ||
              (eq(x.upper_bound, y.upper_bound) && (!x.end_included || y.end_included)))
        in [:point, :range]
          eq(y.lower_bound, x) && y.start_included
        else nil
        end
      end

      def started_by(x, y)
        case shape(x, y)
        in [:range, :range] then starts(y, x)
        in [:range, :point] then starts(y, x)
        else nil
        end
      end

      def coincides(x, y)
        case shape(x, y)
        in [:range, :range]
          eq(x.lower_bound, y.lower_bound) && x.start_included == y.start_included &&
            eq(x.upper_bound, y.upper_bound) && x.end_included == y.end_included
        in [:point, :point]
          eq(x, y)
        else nil
        end
      end
    end

    # The lambda parameters list the parameter names of all signatures of a
    # function (e.g. `before(point1, point2)`, `before(point, range)`,
    # `before(range1, range2)`); positional arguments fill the first signature.
    # range(from): a range value from the text of a range literal, e.g.
    # "[1..10]", "(date(\"2020-01-01\")..date(\"2020-12-31\")]" or "< 5"
    # (DMN 1.5). The endpoints are evaluated without variables.
    def self.parse_range(text)
      return unless text.is_a?(String)

      node = FEEL::Parser.parse(text.strip, root: :range_literal)
      value = node.eval(FEEL::RootScope.build({}))
      value.is_a?(FEEL::Range) ? value : nil
    rescue FEEL::SyntaxError, FEEL::EvaluationError
      nil
    end

    RANGE = {
      "range": ->(from) { Builtins.parse_range(from) },
      "before": ->(point1 = nil, point2 = nil, point = nil, range = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:before, [point1, point2], [point, range], [range1, range2])
      },
      "after": ->(point1 = nil, point2 = nil, point = nil, range = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:after, [point1, point2], [point, range], [range1, range2])
      },
      "meets": ->(range1, range2) {
        RangeRelations.invoke(:meets, [range1, range2])
      },
      "met by": ->(range1, range2) {
        RangeRelations.invoke(:met_by, [range1, range2])
      },
      "overlaps": ->(range1, range2) {
        RangeRelations.invoke(:overlaps, [range1, range2])
      },
      "overlaps before": ->(range1, range2) {
        RangeRelations.invoke(:overlaps_before, [range1, range2])
      },
      "overlaps after": ->(range1, range2) {
        RangeRelations.invoke(:overlaps_after, [range1, range2])
      },
      "finishes": ->(point = nil, range = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:finishes, [point, range], [range1, range2])
      },
      "finished by": ->(range = nil, point = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:finished_by, [range, point], [range1, range2])
      },
      "includes": ->(range = nil, point = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:includes, [range, point], [range1, range2])
      },
      "during": ->(point = nil, range = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:during, [point, range], [range1, range2])
      },
      "starts": ->(point = nil, range = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:starts, [point, range], [range1, range2])
      },
      "started by": ->(range = nil, point = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:started_by, [range, point], [range1, range2])
      },
      "coincides": ->(point1 = nil, point2 = nil, range1 = nil, range2 = nil) {
        RangeRelations.invoke(:coincides, [point1, point2], [range1, range2])
      },
    }.freeze
  end
end
