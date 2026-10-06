# frozen_string_literal: true

require "test_helper"

module FEEL
  describe "FEEL.unparse" do
    def unparse(ast)
      FEEL.unparse(ast)
    end

    def var(*path)
      { type: "name", path: path }
    end

    def number(value)
      { type: "number", value: value }
    end

    def string(value)
      { type: "string", value: value }
    end

    def arithmetic(operator, left, right)
      { type: "arithmetic", operator: operator, left: left, right: right }
    end

    def range(start, finish, start_included, end_included)
      { type: "range", start: start, end: finish, start_included: start_included, end_included: end_included }
    end

    UNPARSED_EXPRESSIONS = [
      "1", "1.5", "0.1", '"a\"b\\\\c\nd"', "true", "false", "null", '@"2020-01-01"', '@"P1D"', '@"10:30:00@Europe/Berlin"',
      "a", "a.b.c", "`first name`.length", "x.time offset", "?",
      "[]", "[1, a]", "{}", '{a: 1, "b c": a, `d e`: 2, f g: 3, "x:y": 4}',
      "a + b - c", "a - (b - c)", "(a + b) * c", "a * b / c", "a / (b * c)", "2 ** 3 ** 2", "2 ** (3 ** 2)", "-x", "-(a + b)", "--x", "-x ** 2", "-(x ** 2)",
      "a = 1", "a != b", "a < 1", "a <= 1", "a > 1", "a >= 1", "(a = b) = c",
      "x between 1 and 10", "x between a + 1 and b * 2", "x instance of number", "x instance of days and time duration", "x instance of list<number>",
      'x in ("A", "B")', "x in [1, 2]", "x in < 10", "x in [1..10)", "x in (]1..10[, > 20)", "x in (? > 1)",
      "a and b and c", "a or b or c", "a or b and c", "(a or b) and c", "not(a) and b",
      "if a then 1 else 2", "if a or b then if c then 1 else 2 else 3", "(if a then 1 else 2) + 1",
      "for i in 1..3, j in l return i * j", "for i in [1, 2] return i", "for x in (if a then l else m) return x",
      "some x in l satisfies x > 1", "every x in l, y in m satisfies x > y",
      "f()", "f(1, a)", 'date and time("2020-01-01T10:00:00")', 'string length("abc")', "a.b(1)", "`my fn`(1)",
      'substring(string: "abc", start position: 2)', "before(1, [2..5))", "before(1, < 5)", "before(1, >= 5)", "before(point: 1, range: (2..5])",
      "function() 1", "function(a: number, b) a + b", "(function(x) x * 2)(21)", "sort(l, function(x, y) x < y)",
      "[1, 2][item > 1]", "a[1].b", "(x).b", "(f)(1)", "f(1)(2)", "{a: [1]}[1].a", "[{a: 1}].a", "(1 + 2).x",
      "< 10", "[1..2]",
    ].freeze

    UNPARSED_TESTS = [nil, "-", "1, 2", '< 10, [20..30), "A", ? > 1', "not(1, 2)", "not(< 10)", "(not(true)), false", "a + 1, [1, 2]"].freeze

    it "should build expressions that parse to the same AST" do
      UNPARSED_EXPRESSIONS.each do |text|
        ast = FEEL.parse(text)
        _(FEEL.parse(unparse(ast))).must_equal ast, "#{text} => #{unparse(ast)}"
      end
    end

    it "should build unary tests that parse to the same AST" do
      UNPARSED_TESTS.each do |text|
        ast = FEEL.parse_test(text)
        _(FEEL.parse_test(unparse(ast))).must_equal ast, "#{text.inspect} => #{unparse(ast)}"
      end
    end

    it "should build a canonical text" do
      _(unparse(FEEL.parse("a+b*  2 // comment"))).must_equal "a + b * 2"
      _(unparse(FEEL.parse("((a))"))).must_equal "a"
      _(unparse(FEEL.parse("[ 1,2 ]"))).must_equal "[1, 2]"
      _(unparse(FEEL.parse("{ a : 1 }"))).must_equal "{a: 1}"
      _(unparse(FEEL.parse("x in [1..2]"))).must_equal "x in ([1..2])"
      _(unparse(FEEL.parse("string  length( x )"))).must_equal "string length(x)"
      _(unparse(FEEL.parse_test("<10,>20"))).must_equal "< 10, > 20"
    end

    it "should build the documented example" do
      ast = {
        type: "conjunction",
        operands: [
          { type: "comparison", operator: ">=", left: var("age"), right: number(18) },
          { type: "in", value: var("status"), tests: [string("A"), string("B")] },
        ],
      }
      _(unparse(ast)).must_equal 'age >= 18 and status in ("A", "B")'
    end

    describe :precedence do
      it "should add parentheses for operands of lower precedence" do
        _(unparse(arithmetic("*", arithmetic("+", var("a"), var("b")), var("c")))).must_equal "(a + b) * c"
        _(unparse(arithmetic("+", var("a"), arithmetic("*", var("b"), var("c"))))).must_equal "a + b * c"
        _(unparse({ type: "negation", value: arithmetic("+", var("a"), var("b")) })).must_equal "-(a + b)"
        _(unparse({ type: "comparison", operator: "=", left: var("a"), right: { type: "comparison", operator: "=", left: var("b"), right: var("c") } })).must_equal "a = (b = c)"
        _(unparse({ type: "conjunction", operands: [{ type: "disjunction", operands: [var("a"), var("b")] }, var("c")] })).must_equal "(a or b) and c"
        _(unparse({ type: "list", items: [{ type: "if", condition: var("a"), then: number(1), else: number(2) }] })).must_equal "[if a then 1 else 2]"
        _(unparse(arithmetic("+", { type: "if", condition: var("a"), then: number(1), else: number(2) }, number(1)))).must_equal "(if a then 1 else 2) + 1"
      end

      it "should respect the left associativity" do
        _(unparse(arithmetic("-", arithmetic("-", var("a"), var("b")), var("c")))).must_equal "a - b - c"
        _(unparse(arithmetic("-", var("a"), arithmetic("-", var("b"), var("c"))))).must_equal "a - (b - c)"
        _(unparse(arithmetic("/", var("a"), arithmetic("*", var("b"), var("c"))))).must_equal "a / (b * c)"
        _(unparse(arithmetic("**", var("a"), arithmetic("**", var("b"), var("c"))))).must_equal "a ** (b ** c)"
      end

      it "should keep paths and invocations of names apart from qualified names and function calls" do
        _(unparse({ type: "path", value: var("x"), property: "y" })).must_equal "(x).y"
        _(unparse({ type: "invocation", function: var("f"), arguments: [number(1)] })).must_equal "(f)(1)"
        _(unparse({ type: "path", value: { type: "function call", name: "f", arguments: [] }, property: "y" })).must_equal "f().y"
        _(unparse({ type: "filter", value: var("l"), filter: number(1) })).must_equal "l[1]"
      end
    end

    describe :literals do
      it "should format numbers" do
        _(unparse(number(42))).must_equal "42"
        _(unparse(number(1.5))).must_equal "1.5"
        _(unparse(number(2.0))).must_equal "2"
        _(unparse(number(1e20))).must_equal "100000000000000000000"
        _(unparse(number(1e-7))).must_equal "0.0000001"
        _(unparse(number(BigDecimal("12.3456789012345678901234567890")))).must_equal "12.345678901234567890123456789"
        _(unparse(number(-5))).must_equal "-5"
        _(unparse(arithmetic("-", var("a"), number(-5)))).must_equal "a - -5"
        _(unparse(arithmetic("**", number(-2), number(2)))).must_equal "-2 ** 2"
        _(FEEL.evaluate(unparse(arithmetic("**", number(-2), number(2))))).must_equal 4
      end

      it "should escape strings" do
        _(unparse(string("a\"b\\c\nd\te\u0001é"))).must_equal '"a\"b\\\\c\nd\te\u0001é"'
        _(FEEL.evaluate(unparse(string("a\"b\\c\nd\te\u0001é")))).must_equal "a\"b\\c\nd\te\u0001é"
      end

      it "should write temporal values" do
        _(unparse({ type: "temporal", text: "2020-01-01" })).must_equal '@"2020-01-01"'
        _(unparse({ type: "temporal", value: Date.new(2020, 1, 2) })).must_equal '@"2020-01-02"'
        _(unparse({ type: "temporal", value: Duration.days(3) })).must_equal '@"P3D"'
        time = Time.new(2020, 7, 1, 10, 30, 0, in: TZInfo::Timezone.get("Europe/Berlin"))
        _(unparse({ type: "temporal", value: time })).must_equal '@"2020-07-01T10:30:00@Europe/Berlin"'
        _(FEEL.evaluate(unparse({ type: "temporal", value: time }))).must_equal time
      end

      it "should write contexts" do
        ast = { type: "context", entries: [{ key: "a b", value: number(1) }, { key: "x:y", value: number(2) }, { key: "1x", value: number(3) }, { key: "null", value: number(4) }] }
        _(unparse(ast)).must_equal '{a b: 1, "x:y": 2, "1x": 3, "null": 4}'
        _(FEEL.evaluate(unparse(ast))).must_equal({ "a b" => 1, "x:y" => 2, "1x" => 3, "null" => 4 })
      end
    end

    describe :names do
      it "should escape names with backticks if need be" do
        _(unparse(var("first name"))).must_equal "`first name`"
        _(unparse(var("a-b", "c d"))).must_equal "`a-b`.`c d`"
        _(unparse(var("and"))).must_equal "`and`"
        _(unparse(var("1a"))).must_equal "`1a`"
        _(unparse(var("ä"))).must_equal "ä"
        _(unparse(var("x", "time offset"))).must_equal "x.time offset"
        _(FEEL.evaluate(unparse(var("first name", "a-b")), variables: { "first name" => { "a-b" => 1 } })).must_equal 1
      end

      it "should escape function and parameter names if need be" do
        _(unparse({ type: "function call", name: "string length", arguments: [string("a")] })).must_equal 'string length("a")'
        _(unparse({ type: "function call", name: "my-fn", arguments: [] })).must_equal "`my-fn`()"
        _(unparse({ type: "function call", name: "not in", arguments: [] })).must_equal "`not in`()"
        _(unparse({ type: "function call", name: "f", named_arguments: [{ name: "a-b", value: number(1) }] })).must_equal "f(`a-b`: 1)"
        _(unparse({ type: "function definition", parameters: [{ name: "a b" }, { name: "c", type: "number" }], body: var("c") })).must_equal "function(a b, c: number) c"
      end

      it "should reject names that can't be written in FEEL" do
        _ { unparse(var("a`b")) }.must_raise AST::Error
        _ { unparse(var("a  b")) }.must_raise AST::Error
        _ { unparse(var(" a")) }.must_raise AST::Error
        _ { unparse(var("")) }.must_raise AST::Error
      end
    end

    describe :tests do
      it "should write ranges and unary comparisons" do
        _(unparse({ type: "in", value: var("x"), tests: [range(number(1), number(10), false, true)] })).must_equal "x in ((1..10])"
        _(unparse({ type: "in", value: var("x"), tests: [range(nil, number(5), false, true)] })).must_equal "x in (<= 5)"
        _(unparse({ type: "in", value: var("x"), tests: [range(number(5), nil, false, false)] })).must_equal "x in (> 5)"
        _(unparse({ type: "unary tests", tests: [{ type: "unary comparison", operator: "<", value: number(1) }, range(number(1), number(2), true, true)] })).must_equal "< 1, [1..2]"
        _(unparse({ type: "function call", name: "before", arguments: [number(1), range(nil, number(5), false, false)] })).must_equal "before(1, < 5)"
      end

      it "should write negated and any unary tests" do
        _(unparse({ type: "not", tests: [number(1), number(2)] })).must_equal "not(1, 2)"
        _(unparse({ type: "any" })).must_equal "-"
      end

      it "should not confuse a call of a function not() with negated tests" do
        ast = { type: "unary tests", tests: [{ type: "function call", name: "not", arguments: [var("a")] }] }
        _(unparse(ast)).must_equal "(not(a))"
        _(FEEL.parse_test(unparse(ast))).must_equal ast
      end
    end

    it "should accept string keys, e.g. an AST read from JSON" do
      ast = JSON.parse(JSON.generate(FEEL.parse('a.b > 1 and c in ("x", [1..2])')))
      _(unparse(ast)).must_equal 'a.b > 1 and c in ("x", [1..2])'
    end

    it "should reject invalid ASTs" do
      [
        nil,
        "a",
        {},
        { type: "foo" },
        { type: "comparison", operator: "<>", left: var("a"), right: number(1) },
        { type: "comparison", operator: "=", left: var("a") },
        { type: "arithmetic", operator: "%", left: var("a"), right: number(1) },
        { type: "number", value: "1" },
        { type: "number", value: Float::NAN },
        { type: "boolean", value: nil },
        { type: "string", value: 1 },
        { type: "name", path: [] },
        { type: "conjunction", operands: [var("a")] },
        { type: "in", value: var("a"), tests: [] },
        { type: "instance of", value: var("a"), of: "not a type!" },
        { type: "list", items: [{ type: "unary comparison", operator: "<", value: number(1) }] },
        { type: "list", items: [range(number(1), number(2), true, true)] },
        { type: "list", items: [{ type: "any" }] },
        { type: "for", iterations: [{ name: "i", in: range(number(1), number(3), false, true) }], return: var("i") },
        { type: "function call", name: "f", arguments: [range(nil, nil, false, false)] },
        { type: "temporal" },
        { type: "unary tests", tests: [] },
      ].each do |ast|
        error = _ { unparse(ast) }.must_raise AST::Error
        _(error).must_be_kind_of FEEL::Error
      end
    end
  end
end
