# frozen_string_literal: true

require "test_helper"

# The AST format of FEEL.parse / FEEL.parse_test is a public API: these tests
# fix it.
module FEEL
  describe "AST" do
    def parse(text)
      FEEL.parse(text)
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

    def range(start, finish, start_included, end_included)
      { type: "range", start: start, end: finish, start_included: start_included, end_included: end_included }
    end

    describe :literals do
      it "should parse numbers" do
        _(parse("42")).must_equal number(42)
        _(parse("1.50")).must_equal number(1.5)
        _(parse("2.0")).must_equal number(2)
        _(parse(".5")).must_equal number(0.5)
      end

      it "should parse strings, booleans and null" do
        _(parse('"a\"b\\n"')).must_equal string("a\"b\n")
        _(parse("'x'")).must_equal string("x")
        _(parse("true")).must_equal({ type: "boolean", value: true })
        _(parse("false")).must_equal({ type: "boolean", value: false })
        _(parse("null")).must_equal({ type: "null" })
      end

      it "should parse temporal literals" do
        _(parse('@"2020-01-01"')).must_equal({ type: "temporal", text: "2020-01-01", value: Date.new(2020, 1, 1) })
        _(parse('@"P1D"')).must_equal({ type: "temporal", text: "P1D", value: Duration.days(1) })
        _(parse('@"invalid"')).must_equal({ type: "temporal", text: "invalid", value: nil })
      end

      it "should parse lists and contexts" do
        _(parse("[]")).must_equal({ type: "list", items: [] })
        _(parse("[1, a]")).must_equal({ type: "list", items: [number(1), var("a")] })
        _(parse("{}")).must_equal({ type: "context", entries: [] })
        _(parse('{a: 1, "b c": a, `d e`: 2, f g: 3}')).must_equal({
          type: "context",
          entries: [
            { key: "a", value: number(1) },
            { key: "b c", value: var("a") },
            { key: "d e", value: number(2) },
            { key: "f g", value: number(3) },
          ],
        })
      end
    end

    describe :names do
      it "should parse names and qualified names" do
        _(parse("age")).must_equal var("age")
        _(parse("person.address.city")).must_equal var("person", "address", "city")
        _(parse("`first name`.length")).must_equal var("first name", "length")
        _(parse("?")).must_equal({ type: "input" })
      end

      it "should parse paths, filters and invocations of expressions" do
        _(parse("[1, 2][item > 1]")).must_equal({
          type: "filter",
          value: { type: "list", items: [number(1), number(2)] },
          filter: { type: "comparison", operator: ">", left: var("item"), right: number(1) },
        })
        _(parse("a[1].b")).must_equal({
          type: "path",
          value: { type: "filter", value: var("a"), filter: number(1) },
          property: "b",
        })
        _(parse("x.time offset")).must_equal var("x", "time offset")
        _(parse("(x).time offset")).must_equal({ type: "path", value: var("x"), property: "time offset" })
        _(parse("f(1)(2)")).must_equal({
          type: "invocation",
          function: { type: "function call", name: "f", arguments: [number(1)] },
          arguments: [number(2)],
        })
      end
    end

    describe :operators do
      it "should parse arithmetic as left-nested binary operations" do
        _(parse("1 + 2 - 3")).must_equal({
          type: "arithmetic", operator: "-",
          left: { type: "arithmetic", operator: "+", left: number(1), right: number(2) },
          right: number(3),
        })
        _(parse("a * b / c")).must_equal({
          type: "arithmetic", operator: "/",
          left: { type: "arithmetic", operator: "*", left: var("a"), right: var("b") },
          right: var("c"),
        })
        _(parse("1 + 2 * 3")).must_equal({
          type: "arithmetic", operator: "+",
          left: number(1),
          right: { type: "arithmetic", operator: "*", left: number(2), right: number(3) },
        })
        _(parse("2 ** 3")).must_equal({ type: "arithmetic", operator: "**", left: number(2), right: number(3) })
        _(parse("-x")).must_equal({ type: "negation", value: var("x") })
        _(parse("(1 + 2) * 3")[:left]).must_equal({ type: "arithmetic", operator: "+", left: number(1), right: number(2) })
      end

      it "should parse comparisons" do
        %w[= != < <= > >=].each do |operator|
          _(parse("a #{operator} 1")).must_equal({ type: "comparison", operator: operator, left: var("a"), right: number(1) })
        end
        _(parse("x between 1 and 10")).must_equal({ type: "between", value: var("x"), low: number(1), high: number(10) })
        _(parse("x instance of  days and time duration")).must_equal({ type: "instance of", value: var("x"), of: "days and time duration" })
        _(parse("x instance of list<number>")[:of]).must_equal "list<number>"
      end

      it "should parse in expressions with their unary tests" do
        _(parse('status in ("A", "B")')).must_equal({ type: "in", value: var("status"), tests: [string("A"), string("B")] })
        _(parse("x in [1, 2]")).must_equal({ type: "in", value: var("x"), tests: [{ type: "list", items: [number(1), number(2)] }] })
        _(parse("x in < 10")).must_equal({
          type: "in", value: var("x"),
          tests: [{ type: "unary comparison", operator: "<", value: number(10) }],
        })
        _(parse("x in (1..10]")).must_equal({ type: "in", value: var("x"), tests: [range(number(1), number(10), false, true)] })
        _(parse("x in ]1..10[")[:tests]).must_equal [range(number(1), number(10), false, false)]
      end

      it "should parse conjunctions and disjunctions" do
        _(parse("a and b and c")).must_equal({ type: "conjunction", operands: [var("a"), var("b"), var("c")] })
        _(parse("a or b and c")).must_equal({
          type: "disjunction",
          operands: [var("a"), { type: "conjunction", operands: [var("b"), var("c")] }],
        })
      end

      it "should parse the documented example" do
        _(parse('age >= 18 and status in ("A", "B")')).must_equal({
          type: "conjunction",
          operands: [
            { type: "comparison", operator: ">=", left: var("age"), right: number(18) },
            { type: "in", value: var("status"), tests: [string("A"), string("B")] },
          ],
        })
      end
    end

    describe :expressions do
      it "should parse if expressions" do
        _(parse("if a then 1 else 2")).must_equal({ type: "if", condition: var("a"), then: number(1), else: number(2) })
      end

      it "should parse for expressions" do
        _(parse("for i in 1..3, j in l return i * j")).must_equal({
          type: "for",
          iterations: [
            { name: "i", in: range(number(1), number(3), true, true) },
            { name: "j", in: var("l") },
          ],
          return: { type: "arithmetic", operator: "*", left: var("i"), right: var("j") },
        })
      end

      it "should parse quantified expressions" do
        satisfies = { type: "comparison", operator: ">", left: var("x"), right: number(1) }
        _(parse("some x in l satisfies x > 1")).must_equal({ type: "some", iterations: [{ name: "x", in: var("l") }], satisfies: satisfies })
        _(parse("every x in l satisfies x > 1")).must_equal({ type: "every", iterations: [{ name: "x", in: var("l") }], satisfies: satisfies })
      end

      it "should parse function calls" do
        _(parse("f()")).must_equal({ type: "function call", name: "f", arguments: [] })
        _(parse('date and time("2020-01-01T10:00:00")')).must_equal({ type: "function call", name: "date and time", arguments: [string("2020-01-01T10:00:00")] })
        _(parse('string  length("a")')[:name]).must_equal "string length"
        _(parse("a.b(1)")).must_equal({ type: "function call", name: "a.b", arguments: [number(1)] })
        _(parse('substring(string: "abc", start position: 2)')).must_equal({
          type: "function call", name: "substring",
          named_arguments: [{ name: "string", value: string("abc") }, { name: "start position", value: number(2) }],
        })
      end

      it "should parse range arguments" do
        _(parse("before(1, [2..5))")[:arguments][1]).must_equal range(number(2), number(5), true, false)
        _(parse("before(1, < 5)")[:arguments][1]).must_equal range(nil, number(5), false, false)
        _(parse("before(1, <= 5)")[:arguments][1]).must_equal range(nil, number(5), false, true)
        _(parse("before(1, > 5)")[:arguments][1]).must_equal range(number(5), nil, false, false)
        _(parse("before(1, >= 5)")[:arguments][1]).must_equal range(number(5), nil, true, false)
      end

      it "should parse function definitions" do
        _(parse("function() 1")).must_equal({ type: "function definition", parameters: [], body: number(1) })
        _(parse("function(a: number, b) a + b")).must_equal({
          type: "function definition",
          parameters: [{ name: "a", type: "number" }, { name: "b", type: nil }],
          body: { type: "arithmetic", operator: "+", left: var("a"), right: var("b") },
        })
      end

      it "should parse a simple positive unary test as an expression" do
        _(parse("< 10")).must_equal({ type: "unary comparison", operator: "<", value: number(10) })
        _(parse("[1..2]")).must_equal range(number(1), number(2), true, true)
      end

      it "should ignore comments and whitespace" do
        _(parse("a /* x */ +\n // y\n 1")).must_equal parse("a+1")
      end

      it "should raise a syntax error for invalid expressions" do
        _ { parse("1 +") }.must_raise FEEL::SyntaxError
        _ { parse("") }.must_raise FEEL::SyntaxError
      end
    end

    describe :unary_tests do
      it "should parse unary tests" do
        _(FEEL.parse_test('< 10, [20..30), "A", ? > 1')).must_equal({
          type: "unary tests",
          tests: [
            { type: "unary comparison", operator: "<", value: number(10) },
            range(number(20), number(30), true, false),
            string("A"),
            { type: "comparison", operator: ">", left: { type: "input" }, right: number(1) },
          ],
        })
      end

      it "should parse negated and any unary tests" do
        _(FEEL.parse_test("not(1, 2)")).must_equal({ type: "not", tests: [number(1), number(2)] })
        _(FEEL.parse_test("-")).must_equal({ type: "any" })
        _(FEEL.parse_test(nil)).must_equal({ type: "any" })
      end

      it "should raise a syntax error for invalid unary tests" do
        _ { FEEL.parse_test("< ") }.must_raise FEEL::SyntaxError
      end
    end

    it "should return a new tree on each call" do
      tree = parse("a + 1")
      tree[:left][:path] << "b"
      _(parse("a + 1")[:left]).must_equal var("a")
    end

    it "should be convertible to JSON" do
      json = JSON.parse(JSON.generate(parse('x > 1.5 and y in ("a", null) or z = @"2020-01-01"')))
      _(json["type"]).must_equal "disjunction"
      _(json["operands"][0]["operands"][0]["right"]).must_equal({ "type" => "number", "value" => 1.5 })
      _(json["operands"][1]["right"]).must_equal({ "type" => "temporal", "text" => "2020-01-01", "value" => "2020-01-01" })
    end

    describe :walk do
      it "should yield each node, parents first" do
        types = AST.walk(parse("f(a, [b.c]) > -1")).map { |node| node[:type] }
        _(types).must_equal ["comparison", "function call", "name", "list", "name", "negation", "number"]
      end

      it "should yield the nodes of entries" do
        names = []
        AST.walk(FEEL.parse('{a: x, b: for i in l return i}')) { |node| names << node[:path] if node[:type] == "name" }
        _(names).must_equal [["x"], ["l"], ["i"]]
      end
    end

    describe :transform do
      it "should rebuild the tree bottom-up" do
        ast = parse("a + b * 2")
        result = AST.transform(ast) do |node|
          node[:type] == "name" ? node.merge(path: ["t", *node[:path]]) : node
        end
        _(result).must_equal parse("t.a + t.b * 2")
        _(ast).must_equal parse("a + b * 2")
      end

      it "should replace nodes with the result of the block" do
        text = AST.transform(parse("a > 1 and b = \"x\"")) do |node|
          case node[:type]
          when "name" then node[:path].join(".")
          when "number" then node[:value].to_s
          when "string" then node[:value].inspect
          when "comparison" then "#{node[:left]} #{node[:operator]} #{node[:right]}"
          when "conjunction" then node[:operands].join(" and ")
          end
        end
        _(text).must_equal 'a > 1 and b = "x"'
      end
    end
  end
end
