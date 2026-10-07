# frozen_string_literal: true

require "test_helper"

module FEEL
  describe "FEEL::AST.variables and FEEL::AST.functions" do
    def variables(text, unary_tests: false)
      AST.variables(AST.from_text(text, unary_tests: unary_tests))
    end

    def functions(text, **options)
      AST.functions(AST.from_text(text), **options)
    end

    describe :variables do
      it "should return the paths of the variables, once, in order" do
        _(variables("a.b + c - a.b * a")).must_equal [%w[a b], %w[c], %w[a]]
        _(variables("1 + 2")).must_equal []
      end

      it "should return names without backticks" do
        _(variables("`first name` + 1")).must_equal [["first name"]]
        _(variables("`first name`.`last name`")).must_equal [["first name", "last name"]]
        _(variables("x.`time offset` + x.time offset")).must_equal [["x", "time offset"]]
        _(variables("`a.b` + a.b")).must_equal [["a.b"], %w[a b]]
      end

      it "should not return iteration variables" do
        _(variables("for i in l return i + j")).must_equal [%w[l], %w[j]]
        _(variables("for i in l, j in i return i + j")).must_equal [%w[l]]
        _(variables("for i in j, j in i return i")).must_equal [%w[j]]
        _(variables("for i in l return partial")).must_equal [%w[l]]
        _(variables("some x in l satisfies x > y")).must_equal [%w[l], %w[y]]
        _(variables("every x in l, y in x satisfies y > z")).must_equal [%w[l], %w[z]]
      end

      it "should not return function parameters" do
        _(variables("function(x, `y z`) x + `y z` + k")).must_equal [%w[k]]
      end

      it "should not return the entries of a context for the following entries" do
        _(variables("{a: 1, b: a + c}")).must_equal [%w[c]]
        _(variables("{a: b, b: 1}")).must_equal [%w[b]]
        _(variables("{a: c, b: {d: a + e}}")).must_equal [%w[c], %w[e]]
        _(variables('{"x y": 1, z: `x y`}')).must_equal []
      end

      it "should not return the entries of a context in its functions" do
        _(variables("{fact: function(n) if n <= 1 then 1 else n * fact(n - 1), r: fact(c)}")).must_equal [%w[c]]
        _(variables("{f: function() later, later: 1}")).must_equal []
      end

      it "should not return the names available in a filter" do
        _(variables("l[item > a]")).must_equal [%w[l], %w[a]]
        _(variables("[{p: b}][p > q]")).must_equal [%w[b], %w[q]]
        _(variables("l[x > 1]")).must_equal [%w[l], %w[x]]
      end

      it "should not return properties of paths" do
        _(variables("(x).y")).must_equal [%w[x]]
        _(variables("a[1].b")).must_equal [%w[a]]
        _(variables("{a: b}.a")).must_equal [%w[b]]
      end

      it "should return the path of a qualified function name" do
        _(variables("a.b.f(x)")).must_equal [%w[a b], %w[x]]
        _(variables("f(x)")).must_equal [%w[x]]
        _(variables("{a: {f: function(v) v}}.a.f(x)")).must_equal [%w[x]]
        _(variables("for a in l return a.f(x)")).must_equal [%w[l], %w[x]]
      end

      it "should return the variables of unary tests" do
        _(variables("< a, [b..c], not(d)", unary_tests: true)).must_equal [%w[a], %w[b], %w[c], %w[d]]
        _(variables("not(a, b)", unary_tests: true)).must_equal [%w[a], %w[b]]
        _(variables("contains(?, a)", unary_tests: true)).must_equal [%w[a]]
        _(variables("-", unary_tests: true)).must_equal []
      end

      it "should accept trees with string keys" do
        _(AST.variables(JSON.parse(JSON.generate(AST.from_text("for i in l return i + `a b`.c"))))).must_equal [["l"], ["a b", "c"]]
      end
    end

    describe :functions do
      it "should return the names of the invoked functions" do
        _(functions('string length("abc") + count([1]) + string length(x)')).must_equal ["string length", "count"]
        _(functions("a.b.f(x)")).must_equal ["a.b.f"]
        _(functions("`my fn`(x)")).must_equal ["my fn"]
        _(functions("f(x)(y)")).must_equal ["f"]
      end

      it "should not return the functions defined in the expression" do
        _(functions("{f: function(x) x + 1, r: f(1)}.r")).must_equal []
        _(functions("{fact: function(n) if n <= 1 then 1 else n * fact(n - 1)}")).must_equal []
        _(functions("(function(g) g(1))(abs)")).must_equal []
        _(functions("for f in fs return f(1)")).must_equal []
      end

      it "should exclude built-in functions on demand" do
        _(functions("decimal(discount(x), 2) + uuid()", builtins: false)).must_equal ["discount"]
        FEEL.config.camunda_extensions = false
        _(functions("decimal(discount(x), 2) + uuid()", builtins: false)).must_equal %w[discount uuid]
      end
    end

    describe "LiteralExpression#named_variables and #named_functions" do
      it "should return the variables as qualified names" do
        expression = LiteralExpression.new(text: "if `my var` > 0 then person.`first name` else other")
        _(expression.named_variables).must_equal ["my var", "person.first name", "other"]
      end

      it "should return the functions" do
        expression = LiteralExpression.new(text: "decimal(discount(x), 2)")
        _(expression.named_functions).must_equal %w[decimal discount]
        _(expression.named_functions(builtins: false)).must_equal %w[discount]
      end

      it "should support unary tests" do
        _(UnaryTests.new(text: "< `max value`, f(x)").named_variables).must_equal ["max value", "x"]
        _(UnaryTests.new(text: "-").named_variables).must_equal []
        _(UnaryTests.new(text: nil).named_variables).must_equal []
      end
    end
  end
end
