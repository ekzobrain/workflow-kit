# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinRangeFunctionTest
module FEEL
  describe "built-in range functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    it "A before() function should return true when a low number is entered before a high number" do
      _(evaluate(' before(1, 10) ')).must_equal true
    end

    it "A before() function should return false when a high number is entered before a low number" do
      _(evaluate(' before(10, 1)')).must_equal false
    end

    it "A before() function should return false when a number is in the range" do
      _(evaluate(' before(1, [1..10])')).must_equal false
    end

    it "A before() function should return true when a number is in the range" do
      _(evaluate(' before(1, (1..10])')).must_equal true
    end

    it "A before() function should return true when a number is not in range" do
      _(evaluate(' before(1, [5..10])')).must_equal true
    end

    it "A before() function should return false when range is including end which is the same as number" do
      _(evaluate(' before([1..10], 10)')).must_equal false
    end

    it "A before() function should return true when range is not including end which is same as number" do
      _(evaluate(' before([1..10), 10)')).must_equal true
    end

    it "A before() function should return true when range is before number" do
      _(evaluate(' before([1..10], 15)')).must_equal true
    end

    it "A before() function should return true when range is before another range" do
      _(evaluate(' before([1..10], [15..20])')).must_equal true
    end

    it "A before() function should return false when range end is included an is start of another range" do
      _(evaluate(' before([1..10], [10..20])')).must_equal false
    end

    it "A before() function should return true when range end is not included an is start of another range" do
      _(evaluate(' before([1..10), [10..20])')).must_equal true
    end

    it "A before() function should return true when range end is included and range start is not included" do
      _(evaluate(' before([1..10], (10..20])')).must_equal true
    end

    it "A before() function should return true because range end is included and point is higher" do
      _(evaluate(' before([1..10], 20)')).must_equal true
    end

    it "A before() function should return false when a number is not in range and after in value with variables" do
      _(evaluate(' before(point:11, range:[5..10])')).must_equal false
    end

    it "A before() function should return true when range end is included and range start is not included using variables for range" do
      _(evaluate(' before(range1:[1..10], range2:(10..20])')).must_equal true
    end

    it "A before() function should return false when a high number is entered before a low number with variables" do
      _(evaluate(' before(point1:10, point2:1)')).must_equal false
    end

    it "A before() function should return true when a high number is entered before a low number with variables" do
      _(evaluate(' before(point1:1, point2:10)')).must_equal true
    end

    it "An after() function should return true when a low is entered after a high number" do
      _(evaluate(' after(10, 5) ')).must_equal true
    end

    it "An after() function should return false when low number is entered after high number" do
      _(evaluate(' after(5, 10)')).must_equal false
    end

    it "An after() function should return true when number is after range" do
      _(evaluate(' after(12, [1..10])')).must_equal true
    end

    it "An after() function should return true when number is after range if number not included in range" do
      _(evaluate(' after(10, [1..10))')).must_equal true
    end

    it "An after() function should return false when number is range end which is included" do
      _(evaluate(' after(10, [1..10])')).must_equal false
    end

    it "An after() function should return false when range includes number" do
      _(evaluate(' after([11..20), 12)')).must_equal false
    end

    it "An after() function should return true range is after number" do
      _(evaluate(' after([11..20], 10)')).must_equal true
    end

    it "An after() function should return true when range is after even when number is same as start which is not included in range" do
      _(evaluate(' after((11..20], 11)')).must_equal true
    end

    it "An after() function should return false when range is after but when number is same as start of range" do
      _(evaluate(' after([11..20], 11)')).must_equal false
    end

    it "An after() function should return true when range is after another range" do
      _(evaluate(' after([11..20], [1..10])')).must_equal true
    end

    it "An after() function should return false when range is not after another range" do
      _(evaluate(' after([1..10], [11..20])')).must_equal false
    end

    it "An after() function should return true when range is after another range even when end of 2nd range overlaps" do
      _(evaluate(' after([11..20], [1..11))')).must_equal true
    end

    it "An after() function should return true when 1st range is after another range even when start of 1st range overlaps but not included" do
      _(evaluate(' after((11..20], [1..11])')).must_equal true
    end

    it "A meets() function should return true when range1 end incl and range2 start incl and range1.end equals range2.start" do
      _(evaluate(' meets([1..5], [5..10]) ')).must_equal true
    end

    it "A meets() function should return false if range1 end not incl. and range2 start incl. even when range1.end equal range2.start" do
      _(evaluate(' meets([1..5),[5..10]) ')).must_equal false
    end

    it "A meets() function should return false if range1 end incl. and range2 start not incl. even when range1.end equal range2.start" do
      _(evaluate(' meets([1..5],(5..10]) ')).must_equal false
    end

    it "A meets() function should return false if range1 end incl. and range2 start incl. but range1.end is not equal range2.start" do
      _(evaluate(' meets([1..5],[6..10]) ')).must_equal false
    end

    it "A met by() function should return true when range1 start incl and range2 end incl and range1.start equals range2.end" do
      _(evaluate(' met by([5..10], [1..5]) ')).must_equal true
    end

    it "A met by() function should return false if range1 start incl. and range2 end not incl. even when range1.start equal range2.end" do
      _(evaluate(' met by([5..10],[1..5)) ')).must_equal false
    end

    it "A met by() function should return false if range1 start not incl. and range2 end incl. even when range1.start equal range2.end" do
      _(evaluate(' met by((5..10],[1..5]) ')).must_equal false
    end

    it "A met by() function should return false if range1 start incl. and range2 end incl. but range1.start is not equal range2.end" do
      _(evaluate(' met by([6..10],[1..5]) ')).must_equal false
    end

    it "An overlaps() function should return true when smaller value range1 and higher value range2 overlaps" do
      _(evaluate(' overlaps([1..5], [3..8]) ')).must_equal true
    end

    it "An overlaps() function should return true when higher value range1 and smaller value range2 overlaps" do
      _(evaluate(' overlaps([3..8],[1..5]) ')).must_equal true
    end

    it "An overlaps() function should return true when range1 fully overlaps range2" do
      _(evaluate(' overlaps([1..8],[3..5]) ')).must_equal true
    end

    it "An overlaps() function should return true when range2 fully overlaps range1" do
      _(evaluate(' overlaps([3..5],[1..8]) ')).must_equal true
    end

    it "An overlaps() function should return false when smaller value range1 has no overlap to higher value range2" do
      _(evaluate(' overlaps([1..5],[6..8]) ')).must_equal false
    end

    it "An overlaps() function should return false when smaller value range2 has no overlap to higher value range1" do
      _(evaluate(' overlaps([6..8],[1..5]) ')).must_equal false
    end

    it "An overlaps() function should return true when range1 end overlaps range2 start both included" do
      _(evaluate(' overlaps([1..5],[5..8]) ')).must_equal true
    end

    it "An overlaps() function should return false when range1 end overlaps range2 start which is not included" do
      _(evaluate(' overlaps([1..5],(5..8]) ')).must_equal false
    end

    it "An overlaps() function should return false when range1 end overlaps range2 start but is not included" do
      _(evaluate(' overlaps([1..5),[5..8]) ')).must_equal false
    end

    it "An overlaps() function should return false when range1 end overlaps range2 start where both is not included" do
      _(evaluate(' overlaps([1..5),(5..8]) ')).must_equal false
    end

    it "An overlaps() function should return true when range1 start overlaps range2 end and both is included" do
      _(evaluate(' overlaps([5..8],[1..5]) ')).must_equal true
    end

    it "An overlaps() function should return false when range1 start overlaps range2 end but is not included" do
      _(evaluate(' overlaps((5..8],[1..5]) ')).must_equal false
    end

    it "An overlaps() function should return false when range1 start overlaps range2 end which is not included" do
      _(evaluate(' overlaps([5..8],[1..5)) ')).must_equal false
    end

    it "An overlaps() function should return false when range1 start overlaps range2 end where both is not included" do
      _(evaluate(' overlaps((5..8],[1..5)) ')).must_equal false
    end

    it "An overlaps before() function should return true when smaller value range1 and higher value range2 overlaps" do
      _(evaluate(' overlaps before([1..5], [3..8]) ')).must_equal true
    end

    it "An overlaps before() function should return false when range1 has no overlaps to range2" do
      _(evaluate(' overlaps before([1..5],[6..8]) ')).must_equal false
    end

    it "An overlaps before() function should return true when range1 end and range2 start overlaps and both are included" do
      _(evaluate(' overlaps before([1..5],[5..8]) ')).must_equal true
    end

    it "An overlaps before() function should return false when range1 end and range2 start overlaps but range2 start not included" do
      _(evaluate(' overlaps before([1..5],(5..8]) ')).must_equal false
    end

    it "An overlaps before() function should return false when range1 end and range2 start overlaps but range1 end not included" do
      _(evaluate(' overlaps before([1..5),[5..8]) ')).must_equal false
    end

    it "An overlaps before() function should return true when range1 and range2 are the same except range2 start and range1 end is not included" do
      _(evaluate(' overlaps before([1..5),(1..5]) ')).must_equal true
    end

    it "An overlaps before() function should return true when range1 and range2 are the same except range2 start is not included" do
      _(evaluate(' overlaps before([1..5],(1..5]) ')).must_equal true
    end

    it "An overlaps before() function should return false when range1 and range2 are the same except range1 end is not included" do
      _(evaluate(' overlaps before([1..5),[1..5]) ')).must_equal false
    end

    it "An overlaps before() function should return false when range1 and range2 are the same" do
      _(evaluate(' overlaps before([1..5],[1..5]) ')).must_equal false
    end

    it "An overlaps after() function should return true when higher value range1 and higher value range2 overlaps" do
      _(evaluate(' overlaps after([3..8],[1..5]) ')).must_equal true
    end

    it "An overlaps after() function should return false when range1 has no overlap on range2" do
      _(evaluate(' overlaps after([6..8],[1..5]) ')).must_equal false
    end

    it "An overlaps after() function should return true when range1 start overlaps range2 end where both is included" do
      _(evaluate(' overlaps after([5..8],[1..5]) ')).must_equal true
    end

    it "An overlaps after() function should return false when range1 start overlaps range2 end which is not included" do
      _(evaluate(' overlaps after([5..8],[1..5)) ')).must_equal false
    end

    it "An overlaps after() function should return ture when range1 start not incl overlaps range2 end not included" do
      _(evaluate(' overlaps after((1..5],[1..5)) ')).must_equal true
    end

    it "An overlaps after() function should return true when range1 start not incl. overlaps range2 all included" do
      _(evaluate(' overlaps after((1..5],[1..5]) ')).must_equal true
    end

    it "An overlaps after() function should return false when range1 all incl. overlaps range2 end not included" do
      _(evaluate(' overlaps after([1..5],[1..5)) ')).must_equal false
    end

    it "An overlaps after() function should return false when range1 and range2 are the same" do
      _(evaluate(' overlaps after([1..5],[1..5]) ')).must_equal false
    end

    it "A finishes() function should return true when point is equal to range end included" do
      _(evaluate(' finishes(10,[1..10]) ')).must_equal true
    end

    it "A finishes() function should return false when point is same as range end not included" do
      _(evaluate(' finishes(10,[1..10)) ')).must_equal false
    end

    it "A finishes() function should return true when range1 end is same as range2 end both included" do
      _(evaluate(' finishes([5..10],[1..10]) ')).must_equal true
    end

    it "A finishes() function should return false when range1 end is same as range2 end but range1 end not included" do
      _(evaluate(' finishes([5..10),[1..10]) ')).must_equal false
    end

    it "A finishes() function should return true when range1 end is same as range2 end both not included" do
      _(evaluate(' finishes([5..10),[1..10)) ')).must_equal true
    end

    it "A finishes() function should return true when range1 is same as range2 all included" do
      _(evaluate(' finishes([1..10],[1..10]) ')).must_equal true
    end

    it "A finishes() function should return true when range1 is same as range2 but range1 start not included" do
      _(evaluate(' finishes((1..10],[1..10]) ')).must_equal true
    end

    it "A finished by() function should return true when range end included and equal to point" do
      _(evaluate(' finished by([1..10], 10) ')).must_equal true
    end

    it "A finished by() function should return false when range end not included and equal to point" do
      _(evaluate(' finished by([1..10), 10) ')).must_equal false
    end

    it "A finished by() function should return true when range1 end is equal to range2 end both included" do
      _(evaluate(' finished by([1..10], [5..10]) ')).must_equal true
    end

    it "A finished by() function should return false when range1 end is equal to range2 end not included" do
      _(evaluate(' finished by([1..10], [5..10)) ')).must_equal false
    end

    it "A finished by() function should return true when range1 end is equal to range2 end and both not included" do
      _(evaluate(' finished by([1..10), [5..10)) ')).must_equal true
    end

    it "A finished by() function should return true when range1 is equal to range2" do
      _(evaluate(' finished by([1..10], [1..10]) ')).must_equal true
    end

    it "A finished by() function should return true when range1 is equal to range2 but range2 start not included" do
      _(evaluate(' finished by([1..10], (1..10]) ')).must_equal true
    end

    it "A includes() function should return true when range includes point" do
      _(evaluate(' includes([1..10], 5) ')).must_equal true
    end

    it "A includes() function should return false when range does not include point" do
      _(evaluate(' includes([1..10], 12) ')).must_equal false
    end

    it "A includes() function should return true when range start is included and equal to point" do
      _(evaluate(' includes([1..10], 1) ')).must_equal true
    end

    it "A includes() function should return true when range end is included and equal to point" do
      _(evaluate(' includes([1..10], 10) ')).must_equal true
    end

    it "A includes() function should return false when range start is not included and range start is equal to point" do
      _(evaluate(' includes((1..10], 1) ')).must_equal false
    end

    it "A includes() function should return false when range end is not included and range start is equal to point" do
      _(evaluate(' includes([1..10), 10) ')).must_equal false
    end

    it "A includes() function should return true when range2 is middle part of range1" do
      _(evaluate(' includes([1..10], [4..6]) ')).must_equal true
    end

    it "A includes() function should return true when range2 is start part of range1" do
      _(evaluate(' includes([1..10], [1..5]) ')).must_equal true
    end

    it "A includes() function should return true when range2 is start part of range1 and both are not including start" do
      _(evaluate(' includes((1..10], (1..5]) ')).must_equal true
    end

    it "A includes() function should return true when range2 is part of range1 and range 2 start and end is not included" do
      _(evaluate(' includes([1..10], (1..10)) ')).must_equal true
    end

    it "A includes() function should return true when range2 is end part of range1 and both does not have end included" do
      _(evaluate(' includes([1..10), [5..10)) ')).must_equal true
    end

    it "A includes() function should return true when range2 equal to range1 and range2 end is not included" do
      _(evaluate(' includes([1..10], [1..10)) ')).must_equal true
    end

    it "A includes() function should return true when range2 equal to range1 and range2 start is not included" do
      _(evaluate(' includes([1..10], (1..10]) ')).must_equal true
    end

    it "A includes() function should return true when range1 and range2 is equal" do
      _(evaluate(' includes([1..10], [1..10]) ')).must_equal true
    end

    it "A during() function should return true when point is in range" do
      _(evaluate(' during(5, [1..10]) ')).must_equal true
    end

    it "A during() function should return false when point not in range" do
      _(evaluate(' during(12, [1..10]) ')).must_equal false
    end

    it "A during() function should return true when point equal to range start included" do
      _(evaluate(' during(1, [1..10]) ')).must_equal true
    end

    it "A during() function should return ture when point is equal to range end included" do
      _(evaluate(' during(10, [1..10]) ')).must_equal true
    end

    it "A during() function should return false when point is equal to range start not included" do
      _(evaluate(' during(1, (1..10]) ')).must_equal false
    end

    it "A during() function should return false when point is equal to range end not included" do
      _(evaluate(' during(10, [1..10)) ')).must_equal false
    end

    it "A during() function should return true when range1 is part of range2" do
      _(evaluate(' during([4..6], [1..10]) ')).must_equal true
    end

    it "A during() function should return true when range1 is part the start of range2" do
      _(evaluate(' during([1..5], [1..10]) ')).must_equal true
    end

    it "A during() function should return true when range1 is part the start of range2 both starts not included" do
      _(evaluate(' during((1..5], (1..10]) ')).must_equal true
    end

    it "A during() function should return true when range1 is part of range2 and range1 start and end not included" do
      _(evaluate(' during((1..10), [1..10]) ')).must_equal true
    end

    it "A during() function should return true when range1 is equal to range2 both ranges end not included" do
      _(evaluate(' during([5..10), [1..10)) ')).must_equal true
    end

    it "A during() function should return true when range1 equal to range2 and range1 end not included" do
      _(evaluate(' during([1..10), [1..10]) ')).must_equal true
    end

    it "A during() function should return true when range1 equal to range2 and range1 start not included" do
      _(evaluate(' during((1..10], [1..10]) ')).must_equal true
    end

    it "A during() function should return true when range1 equal to range2" do
      _(evaluate(' during([1..10], [1..10]) ')).must_equal true
    end

    it "A starts() function should return true when point is equal to range start" do
      _(evaluate(' starts(1, [1..10]) ')).must_equal true
    end

    it "A starts() function should return false when point is equal to range start not included" do
      _(evaluate(' starts(1, (1..10]) ')).must_equal false
    end

    it "A starts() function should return false when point is not equal to range start" do
      _(evaluate(' starts(2, [1..10]) ')).must_equal false
    end

    it "A starts() function should return true when range1 start is equal to range2 start both included" do
      _(evaluate(' starts([1..5], [1..10]) ')).must_equal true
    end

    it "A starts() function should return true when range1 start is equal to range2 start both not included" do
      _(evaluate(' starts((1..5], (1..10]) ')).must_equal true
    end

    it "A starts() function should return false when range1 start is equal to range2 start but range1 start not included" do
      _(evaluate(' starts((1..5], [1..10]) ')).must_equal false
    end

    it "A starts() function should return false when range1 start is equal to range2 start which is not included" do
      _(evaluate(' starts([1..5], (1..10]) ')).must_equal false
    end

    it "A starts() function should return true range1 is equal to range2" do
      _(evaluate(' starts([1..10], [1..10]) ')).must_equal true
    end

    it "A starts() function should return true when range1 is equal to range2 but range1 end not included" do
      _(evaluate(' starts([1..10), [1..10]) ')).must_equal true
    end

    it "A starts() function should return true when range1 is equal to range2 where start and end not included" do
      _(evaluate(' starts((1..10), (1..10)) ')).must_equal true
    end

    it "A started by() function should return true when range start is equal to point" do
      _(evaluate(' started by([1..10], 1) ')).must_equal true
    end

    it "A started by() function should return false when range start is equal to point but range start not included" do
      _(evaluate(' started by((1..10], 1) ')).must_equal false
    end

    it "A started by() function should return false when range start is not equal to point" do
      _(evaluate(' started by((1..10], 2) ')).must_equal false
    end

    it "A started by() function should return true when range1 start is equal to range2 start" do
      _(evaluate(' started by([1..10], [1..5]) ')).must_equal true
    end

    it "A started by() function should return true when range1 start is equal to range2 start even when both ranges does not have start included" do
      _(evaluate(' started by((1..10], (1..5]) ')).must_equal true
    end

    it "A started by() function should return false when range1 start is equal to range2 start which is not included" do
      _(evaluate(' started by([1..10], (1..5]) ')).must_equal false
    end

    it "A started by() function should return false when range1 start is equal to range2 start but range1 start is not included" do
      _(evaluate(' started by((1..10], [1..5]) ')).must_equal false
    end

    it "A started by() function should return true when range1 is equal to range2" do
      _(evaluate(' started by([1..10], [1..10]) ')).must_equal true
    end

    it "A started by() function should return true when range1 is equal to range2 where range2 end not included" do
      _(evaluate(' started by([1..10], [1..10)) ')).must_equal true
    end

    it "A started by() function should return true when range1 is equal to range2 where both ranges does not include end and start" do
      _(evaluate(' started by((1..10), (1..10)) ')).must_equal true
    end

    it "A coincides() function should return true when point1 is equal to point2" do
      _(evaluate(' coincides(5, 5) ')).must_equal true
    end

    it "A coincides() function should return false when point1 is not equal to point2" do
      _(evaluate(' coincides(3, 4) ')).must_equal false
    end

    it "A coincides() function should return true when range1 is equal to range2" do
      _(evaluate(' coincides([1..5], [1..5]) ')).must_equal true
    end

    it "A coincides() function should return false when range1 is not equal to range2 because of range1 end and start is not included" do
      _(evaluate(' coincides((1..5), [1..5]) ')).must_equal false
    end

    it "A coincides() function should return false when range1 is not equal to range2" do
      _(evaluate(' coincides([1..5], [2..6]) ')).must_equal false
    end

    it "A range function should support numbers" do
      _(evaluate(' before(1, 10) ')).must_equal true
      _(evaluate(' before(1, [1..10])')).must_equal false
    end

    it "A range function should support date values" do
      _(evaluate(' before(date("2021-12-21"), date("2021-12-24")) ')).must_equal true
      _(evaluate(' before(date("2021-12-21"), [date("2021-12-01")..date("2021-12-24")])')).must_equal false
    end

    it "A range function should support time values" do
      _(evaluate(' before(time("12:00:00+01:00"), time("13:00:00+01:00")) ')).must_equal true
      _(evaluate(' before(time("12:00:00+01:00"), [time("10:00:00+01:00")..time("13:00:00+01:00")])')).must_equal false
    end

    it "A range function should support time values (local)" do
      _(evaluate(' before(time("12:00:00"), time("13:00:00")) ')).must_equal true
      _(evaluate(' before(time("12:00:00"), [time("10:00:00")..time("13:00:00")])')).must_equal false
    end

    it "A range function should support date-time values" do
      _(evaluate(' before(date and time("2021-12-21T12:00:00+01:00"), date and time("2021-12-24T12:00:00+01:00")) ')).must_equal true
      _(evaluate(' before(date and time("2021-12-21T12:00:00+01:00"), [date and time("2021-12-01T12:00:00+01:00")..date and time("2021-12-24T12:00:00+01:00")])')).must_equal false
    end

    it "A range function should support date-time values (local)" do
      _(evaluate(' before(date and time("2021-12-21T12:00:00"), date and time("2021-12-24T12:00:00")) ')).must_equal true
      _(evaluate(' before(date and time("2021-12-21T12:00:00"), [date and time("2021-12-01T12:00:00")..date and time("2021-12-24T12:00:00")])')).must_equal false
    end

    it "A range function should support year-month-duration values" do
      _(evaluate(' before(duration("P3M"), duration("P6M")) ')).must_equal true
      _(evaluate(' before(duration("P3M"), [duration("P1M")..duration("P6M")])')).must_equal false
    end

    it "A range function should support days-times-duration values" do
      _(evaluate(' before(duration("PT3H"), duration("PT6H")) ')).must_equal true
      _(evaluate(' before(duration("PT3H"), [duration("PT1H")..duration("PT6H")])')).must_equal false
    end

    it "A range function should return null for string values" do
      _(evaluate(' before("a", "b") ')).must_be_nil
      _(evaluate(' before("a", [1..5]) ')).must_be_nil
    end

    it "A range function should return null for boolean values" do
      _(evaluate(' before(true, false) ')).must_be_nil
      _(evaluate(' before(true, [1..5]) ')).must_be_nil
    end

    it "A range function should return null for list values" do
      _(evaluate(' before([1,2], [3,4]) ')).must_be_nil
      _(evaluate(' before([1,2], [1..5]) ')).must_be_nil
    end

    it "A range function should return null for context values" do
      _(evaluate(' before({}, {x:1}) ')).must_be_nil
      _(evaluate(' before({}, [1..5]) ')).must_be_nil
    end

    it "A range function should return null for null values" do
      _(evaluate(' before(null, 5) ')).must_be_nil
      _(evaluate(' before(1, null) ')).must_be_nil
      _(evaluate(' before(null, [1..5]) ')).must_be_nil
      _(evaluate(' before(1, null) ')).must_be_nil
    end

    it "A range function should return null if the value types are different" do
      _(evaluate(' before(5, date("2021-12-21")) ')).must_be_nil
      _(evaluate(' before(date("2021-12-21"), [1..5]) ')).must_be_nil
    end
  end

  # Additional tests (not from feel-scala): range values.
  describe "range values" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    it "should be created by a range function argument" do
      _(evaluate("f([1..10))", f: ->(r) { r })).must_equal Range.new(1, 10, true, false)
      _(evaluate("f(]1..10[)", f: ->(r) { r })).must_equal Range.new(1, 10, false, false)
      _(evaluate("f(< 5)", f: ->(r) { r })).must_equal Range.new(nil, 5, false, false)
      _(evaluate("f(>= x)", f: ->(r) { r }, x: 5)).must_equal Range.new(5, nil, true, false)
      _(evaluate('f(["a".."z"])', f: ->(r) { r })).must_equal Range.new("a", "z")
      _(evaluate("(function(r) r)(r: [1..x])", x: 3)).must_equal Range.new(1, 3)
    end

    it "should be null for an invalid range definition" do
      _(evaluate('f([1.."z"])', f: ->(r) { r })).must_be_nil
      _(evaluate("f([1..null])", f: ->(r) { r })).must_be_nil
    end

    it "should support open-ended ranges in range functions" do
      _(evaluate("before(1, > 5)")).must_equal true
      _(evaluate("includes(< 5, 3)")).must_equal true
      _(evaluate("includes(< 5, 5)")).must_equal false
      _(evaluate("overlaps(< 5, [3..8])")).must_equal true
    end

    it "should test membership in a unary test" do
      range = Range.new(1, 5, true, false)
      _(FEEL.test(3, "r", variables: { r: range })).must_equal true
      _(FEEL.test(5, "r", variables: { r: range })).must_equal false
      _(FEEL.test(5, "r, 5", variables: { r: range })).must_equal true
      _(FEEL.test(3, "not(r)", variables: { r: range })).must_equal false
      _(FEEL.test("m", "r", variables: { r: Range.new("a", "z") })).must_equal true
      _(FEEL.test(Date.new(2021, 12, 5), "r", variables: { r: Range.new(Date.new(2021, 12, 1), Date.new(2021, 12, 24)) })).must_equal true
      _(FEEL.test(3, "r", variables: { r: Range.new(nil, 5, false, false) })).must_equal true
    end

    it "should test membership with in" do
      _(evaluate("x in r", x: 3, r: Range.new(1, 5))).must_equal true
      _(evaluate("x in r", x: 6, r: Range.new(1, 5))).must_equal false
      _(evaluate("x in (r, 10)", x: 10, r: Range.new(1, 5))).must_equal true
      _(evaluate("x in r", x: "a", r: Range.new(1, 5))).must_be_nil
    end

    it "should keep intervals as unary tests" do
      _(evaluate("x in [1..10]", x: 5)).must_equal true
      _(evaluate("[1..10]", "?" => 5)).must_equal true
      _(FEEL.test(5, "[1..10]")).must_equal true
      _(evaluate("[1, 2][2]")).must_equal 2
    end

    it "should compare ranges" do
      _(evaluate("r = s", r: Range.new(1, 5), s: Range.new(1, 5))).must_equal true
      _(evaluate("r = s", r: Range.new(1, 5), s: Range.new(1, 5, false))).must_equal false
    end

    it "should have a FEEL string representation" do
      _(Range.new(1, 10, false, true).to_feel_string).must_equal "(1..10]"
      _(Range.new(1, 10).to_s).must_equal "[1..10]"
      _(Range.new(nil, 5, false, false).to_feel_string).must_equal "< 5"
      _(Range.new(5, nil, true, false).to_feel_string).must_equal ">= 5"
      _(Range.new(1, 10, false, true).to_json).must_equal '"(1..10]"'
    end
  end
end
