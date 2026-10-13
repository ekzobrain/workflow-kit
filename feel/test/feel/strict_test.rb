# frozen_string_literal: true

require "test_helper"

module FEEL
  describe "strict mode and warnings" do
    CONTEXT = { "price" => 10, "qty" => nil, "name" => "abc", "list" => [1, 2], "empty" => [], "obj" => { "a" => 1 } }.freeze

    def lenient(text, variables = CONTEXT)
      FEEL.evaluate(text, variables: variables)
    end

    def strict(text, variables = CONTEXT)
      FEEL.evaluate(text, variables: variables, strict: true)
    end

    def strict_error(text, variables = CONTEXT)
      assert_raises(EvaluationError) { strict(text, variables) }
    end

    def warnings(text, variables = CONTEXT)
      [].tap { |warnings| FEEL.evaluate(text, variables: variables, warnings: warnings) }
    end

    describe "null" do
      it "should stay null in strict mode where FEEL defines it" do
        {
          "price * qty" => nil, "qty = null" => true, "if qty = null then 0 else qty" => 0, "sum([1, qty])" => nil,
          "max(empty)" => nil, "count(empty)" => 0, "upper case(qty)" => nil, "qty or true" => true, "qty and true" => nil,
          "not(qty)" => nil, "list[5]" => nil, 'get value(obj, "zz")' => nil, "if qty then 1 else 2" => 2, "sqrt(-1)" => nil,
          "median([])" => nil, "stddev([1])" => nil, 'from json("null")' => nil, "qty.x" => nil,
        }.each do |text, result|
          _(lenient(text)).must_equal(result, text) unless result.nil?
          _(strict(text)).must_equal(result, text) unless result.nil?
          _(strict(text)).must_be_nil(text) if result.nil?
        end
      end

      it "should be reported as a warning" do
        _(warnings("price * qty").map(&:reason)).must_equal [:null_operand]
        _(warnings("upper case(qty)").map(&:reason)).must_equal [:null_operand]
        _(warnings("qty or true").map(&:reason)).must_equal [:null_operand]
        _(warnings("qty = null")).must_be_empty
        _(warnings("max(empty)")).must_be_empty
      end
    end

    describe "errors" do
      {
        "missing" => :unknown_variable,
        "missing + 1" => :unknown_variable,
        "obj.missing" => :no_context_entry,
        "{a: 1}.b" => :no_context_entry,
        "nope(price)" => :unknown_function,
        "price(1)" => :unknown_function,
        "substring(name)" => :arguments,
        "(function(x) x)(1, 2)" => :arguments,
        "(function(x) x)(y: 1)" => :arguments,
        "name + 1" => :type_mismatch,
        "price + name" => :type_mismatch,
        "-name" => :type_mismatch,
        "price > name" => :type_mismatch,
        "price = name" => :type_mismatch,
        "price between name and 5" => :type_mismatch,
        "name and true" => :type_mismatch,
        "name or false" => :type_mismatch,
        "if name then 1 else 2" => :type_mismatch,
        "some x in list satisfies x" => :type_mismatch,
        "for x in price return x" => :type_mismatch,
        "price[1]" => :type_mismatch,
        "[1, 2][item > name]" => :type_mismatch,
        "upper case(price)" => :invalid_argument,
        "string length(price)" => :invalid_argument,
        "floor(name)" => :invalid_argument,
        "not(name)" => :invalid_argument,
        "count(price)" => :invalid_argument,
        "sum([1, name])" => :invalid_argument,
        "max([1, name])" => :invalid_argument,
        'date("2026-13-45")' => :invalid_argument,
        "date(name)" => :invalid_argument,
        "number(name)" => :invalid_argument,
        'duration("P1X")' => :invalid_argument,
        'matches("a", "[")' => :invalid_argument,
        'from json("{")' => :invalid_argument,
        'get value(price, "a")' => :invalid_argument,
        "price / 0" => :division_by_zero,
        "modulo(price, 0)" => :division_by_zero,
        'duration("P1D") / duration("PT0S")' => :division_by_zero,
        "name.x" => :not_a_context,
        "list.a" => :not_a_context,
        'date("2020-01-01").hour' => :not_a_context,
        "assert(price, price < 5)" => :assertion,
      }.each do |text, reason|
        it "should raise #{reason} for #{text}" do
          lenient_result = lenient(text)
          _(strict_error(text).reason).must_equal reason
          _(warnings(text).map(&:reason)).must_include reason
          _(lenient(text)).must_equal lenient_result unless lenient_result.nil?
        end
      end

      it "should keep the lenient results" do
        _(lenient("name + 1")).must_be_nil
        _(lenient("if name then 1 else 2")).must_equal 2
        _(lenient("list.a")).must_equal [nil, nil]
        _(lenient("obj.missing")).must_be_nil
        _(lenient('date("2026-13-45")')).must_be_nil
      end

      it "should tell which part of the expression failed" do
        error = strict_error('if price > 5 then name + 1 else date("2026-13-45")')
        _(error.message).must_equal %(Can't add "abc" and 1)
        _(error.expression).must_equal "name + 1"
        _(error.position).must_equal 18...26

        error = strict_error('1 + date("2026-13-45")')
        _(error.expression).must_equal 'date("2026-13-45")'
        _(error.message).must_equal %(Function 'date' can't be applied to "2026-13-45")

        _(strict_error("obj.missing").message).must_equal "Identifier obj.missing not found."
        _(strict_error("obj.b").message).must_equal "Identifier obj.b not found. Did you mean obj.a?"
        _(strict_error("{a: 1}.b").expression).must_equal "{a: 1}.b"
        _(strict_error("name.x").message).must_equal %(No property 'x' of "abc")
        _(strict_error('date("2020-01-01").hour').message).must_equal "No property 'hour' of 2020-01-01. Available properties: year, month, day, weekday"
        _(strict_error("assert(price, price < 5)").expression).must_equal "assert(price, price < 5)"
      end

      it "should be FEEL errors" do
        _(strict_error("name + 1")).must_be_kind_of FEEL::Error
      end
    end

    describe "existence checks" do
      it "should not raise for a missing name or context entry compared with null" do
        {
          "obj.missing = null" => true, "obj.missing != null" => false, "null = obj.missing" => true,
          "if obj.missing != null then 1 else 2" => 2, "if obj.missing = null then 0 else obj.missing" => 0,
          "obj.missing.x = null" => true, "missing = null" => true, "missing.x != null" => false,
          "is defined(obj.missing)" => false, "is defined(missing)" => false, "is defined(obj.a)" => true,
          "get or else(obj.missing, 0)" => 0, "get or else(missing, 0)" => 0, "not(obj.missing = null)" => false,
          "({a: 1}).b = null" => true,
        }.each do |text, result|
          _(strict(text)).must_equal result, text
        end
      end

      it "should still report them as warnings" do
        _(warnings("obj.missing = null").map(&:reason)).must_equal [:no_context_entry]
        _(warnings("is defined(missing)").map(&:reason)).must_equal [:unknown_variable]
      end

      it "should raise when the value is used" do
        ["obj.missing + 1", "obj.missing = 1", "obj.missing > 1", "obj.missing = obj.other", "[obj.missing, 1]",
         "string(obj.missing)", "if obj.missing then 1 else 2", "obj.missing in (1, 2)"].each do |text|
          _(strict_error(text).reason).must_equal :no_context_entry, text
        end
      end
    end

    describe "options" do
      it "should default to the configuration" do
        _(lenient("name + 1")).must_be_nil
        FEEL.config.strict = true
        _ { lenient("name + 1") }.must_raise EvaluationError
        _(FEEL.evaluate("name + 1", variables: CONTEXT, strict: false)).must_be_nil
      end

      it "should be accepted by compiled expressions and unary tests" do
        expression = FEEL.compile("a + 1")
        _(expression.evaluate(a: 1)).must_equal 2
        _(expression.evaluate({ a: "x" })).must_be_nil
        _ { expression.evaluate({ a: "x" }, strict: true) }.must_raise EvaluationError
        collected = []
        expression.evaluate({ a: "x" }, warnings: collected)
        _(collected.map(&:reason)).must_equal [:type_mismatch]

        _(FEEL.test(5, "< 10", strict: true)).must_equal true
        _(FEEL.test("a", "< 10")).must_equal false
        _ { FEEL.test("a", "< 10", strict: true) }.must_raise EvaluationError
        _ { FEEL.test(1, '"a", 1', strict: true) }.must_raise EvaluationError
        _ { FEEL.compile_test("< 10").test("a", {}, strict: true) }.must_raise EvaluationError
        _(FEEL.test(nil, "< 10", strict: true)).must_equal false
      end

      it "should reject unknown options" do
        _ { FEEL.compile("1").evaluate({}, strcit: true) }.must_raise ArgumentError
      end

      it "should collect the warnings" do
        collected = []
        _(FEEL.evaluate("x + 1", warnings: collected)).must_be_nil
        _(collected.map { |warning| [warning.reason, warning.message, warning.expression, warning.position] }).must_equal [
          [:unknown_variable, "Identifier x not found.", "x", 0...1],
          [:null_operand, "Can't add null and 1", "x + 1", 0...5],
        ]
        _(collected.first.to_s).must_equal "Identifier x not found."
      end

      it "should raise the first error and collect the warnings before it" do
        collected = []
        error = assert_raises(EvaluationError) { FEEL.evaluate("[price * qty, name + 1]", variables: CONTEXT, strict: true, warnings: collected) }
        _(error.reason).must_equal :type_mismatch
        _(collected.map(&:reason)).must_equal %i[null_operand type_mismatch]
      end
    end

    describe "scope" do
      it "should reach everything evaluated in the expression" do
        ["[1, 2][item + name > 1]", "for x in list return x + name", "some x in list satisfies x + name > 1",
         "{a: name + 1}.a", "(function(x) x + name)(1)", "sort(list, function(x, y) x + name < y)",
         "{f: function(x) x + name, r: f(1)}.r"].each do |text|
          _(strict_error(text).reason).must_equal :type_mismatch, text
          _(lenient(text)).wont_equal(:error, text)
        end
      end

      it "should report the failures of custom functions" do
        FEEL.config.functions = { "boom" => ->(_x) { raise ArgumentError, "bad input" }, "nothing" => ->(_x) {} }
        _(lenient("boom(1)")).must_be_nil
        _(strict("nothing(1)")).must_be_nil
        error = strict_error("boom(1)")
        _(error.reason).must_equal :function_failure
        _(error.message).must_equal "Function 'boom' failed: bad input"
        _(error.cause).must_be_kind_of ArgumentError
        _(strict_error("f(1)", { "f" => ->(_x) { raise "no" } }).reason).must_equal :function_failure
      end

      it "should use the default options for an evaluation inside a custom function" do
        FEEL.config.functions = { "inner" => ->(text) { FEEL.evaluate(text, variables: { "name" => "abc" }) } }
        _(strict('inner("name + 1")')).must_be_nil
        _(strict_error('[inner("name + 1"), name + 1]').expression).must_equal "name + 1"
      end

      it "should be per thread" do
        entered = Queue.new
        release = Queue.new
        FEEL.config.functions = { "pause" => ->(x) { entered << true; release.pop; x } }
        thread = Thread.new do
          FEEL.evaluate("pause(1) + name", variables: CONTEXT, strict: true)
        rescue EvaluationError => e
          e
        end
        entered.pop
        _(lenient("name + 1")).must_be_nil
        release << true
        _(thread.value).must_be_kind_of EvaluationError
        _(Diagnostics.enabled).must_equal false
      end
    end

    # Ported from feel-scala: SuppressedFailuresTest (suppressed failures are
    # warnings here).
    describe "feel-scala suppressed failures" do
      {
        "x + 1" => %i[unknown_variable null_operand],
        "{x: 1}.y" => %i[no_context_entry],
        '@"P1Y".days' => %i[not_a_context],
        "true < 2" => %i[type_mismatch],
        "2 + true" => %i[type_mismatch],
        "if 5 then 1 else 2" => %i[type_mismatch],
        "true and 2" => %i[type_mismatch],
        "false or 3" => %i[type_mismatch],
        "some x in [false, 2] satisfies x" => %i[type_mismatch],
        "every x in [true, 3] satisfies x" => %i[type_mismatch],
      }.each do |text, reasons|
        it "should report #{reasons.join(", ")} for #{text}" do
          _(warnings(text, {}).map(&:reason)).must_equal reasons
        end
      end

      it "should report a failure if the input is not comparable with an interval" do
        collected = []
        FEEL.test("NaN", "[2..5]", warnings: collected)
        _(collected.map(&:reason)).must_equal %i[type_mismatch type_mismatch]
      end
    end
  end
end
