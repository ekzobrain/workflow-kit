# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterContextExpressionTest
module FEEL
  describe "context expressions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    def parses?(expression)
      LiteralExpression.new(text: expression).valid?
    end

    describe "A context" do
      it "access previous entries within the same context" do
        _(evaluate("{a:1, b:a+1, c:b+1}")).must_equal({ "a" => 1, "b" => 2, "c" => 3 })
      end

      it "access previous entries of outer context" do
        _(evaluate("{a:1, b:{c:a+2}}")).must_equal({ "a" => 1, "b" => { "c" => 3 } })
      end

      it "not override variables of nested context" do
        _(evaluate("{ a:1, b:{ a:2, c:a+3 } }")).must_equal({ "a" => 1, "b" => { "a" => 2, "c" => 5 } })
      end

      it "access a previous entry if there is a variable with the same name (static context)" do
        _(evaluate("{a:1, b:a+1}", a: 0)).must_equal({ "a" => 1, "b" => 2 })
      end

      # Adapted: the Scala CustomContext is replaced by a HashWithIndifferentAccess
      it "access a previous entry if there is a variable with the same name (custom context)" do
        _(evaluate("{a:1, b:a+1}", { "a" => 0 }.with_indifferent_access)).must_equal({ "a" => 1, "b" => 2 })
      end

      it "be compared with '='" do
        _(evaluate("{} = {}")).must_equal true
        _(evaluate("{x:1} = {x:1}")).must_equal true
        _(evaluate("{x:{ y:1 }} = {x:{ y:1 }}")).must_equal true

        _(evaluate("{} = {x:1}")).must_equal false
        _(evaluate("{x:1} = {}")).must_equal false
        _(evaluate("{x:1} = {x:2}")).must_equal false
        _(evaluate("{x:1} = {y:1}")).must_equal false

        _(evaluate("{x:1} = {x:true}")).must_equal false
      end

      it "be compared with '!='" do
        _(evaluate("{} != {}")).must_equal false
        _(evaluate("{x:1} != {x:1}")).must_equal false
        _(evaluate("{x:{ y:1 }} != {x:{ y:1 }}")).must_equal false

        _(evaluate("{} != {x:1}")).must_equal true
        _(evaluate("{x:1} != {}")).must_equal true
        _(evaluate("{x:1} != {x:2}")).must_equal true
        _(evaluate("{x:1} != {y:1}")).must_equal true

        _(evaluate("{x:1} != {x:true}")).must_equal true
      end

      it "be accessed and compared" do
        _(evaluate("{x:1}.x = 1")).must_equal true
      end

      it "return null if compare to not a context" do
        _(evaluate("{} = 1")).must_be_nil
      end

      it "fail when special symbols violate context syntax" do
        _(parses?("{foo{bar:1}.`foo{bar` = 1")).must_equal false
        _(parses?("{foo,bar:1}.`foo,bar` = 1")).must_equal false
        _(parses?("{foo:bar:1}.`foo:bar` = 1")).must_equal false
      end
    end

    describe "A context path expression" do
      it "return the value (with literal)" do
        _(evaluate("{a:1}.a")).must_equal 1
      end

      it "return the value (with variable)" do
        _(evaluate("a.b", a: { "b" => 1 })).must_equal 1
      end

      it "return a nested context" do
        _(evaluate("{a: {b:1}}.a")).must_equal({ "b" => 1 })
      end

      it "return the value of the nested context" do
        _(evaluate("{a: {b:1}}.a.b")).must_equal 1
      end

      it "return the value of a previous nested context entry" do
        _(evaluate("{a:{b:1}, c:a.b+1}")).must_equal({ "a" => { "b" => 1 }, "c" => 2 })
      end

      it "return null if the context is empty" do
        _(evaluate("{}.x")).must_be_nil
      end

      it "return null if no entry exists with the key" do
        _(evaluate("{x:1, y:2}.z")).must_be_nil
      end

      it "return null if the context is null" do
        _(evaluate("a.b", a: nil)).must_be_nil
      end

      it "return null if the chained context is null" do
        _(evaluate("{a:1}.b.c")).must_be_nil
      end

      it "return null if the context is empty (inside a context)" do
        _(evaluate("{x:1, y:{}.z}")).must_equal({ "x" => 1, "y" => nil })
      end

      it "return the value of a key with whitespaces" do
        _(evaluate("{foo bar:1}.`foo bar`")).must_equal 1
        _(evaluate("{foo   bar:2}.`foo   bar`")).must_equal 2
        _(evaluate("{foo bar:3, fizz buzz: 4}.`fizz buzz`")).must_equal 4
      end

      it "return the value of a key with special symbols" do
        _(evaluate("{foo+bar:1}.`foo+bar`")).must_equal 1
        _(evaluate("{foo+bar:1, simple_special++char:4}.`simple_special++char`")).must_equal 4
        _(evaluate("{\u{1F40E}:\"\u{1F600}\"}.`\u{1F40E}`")).must_equal "\u{1F600}"
        _(evaluate(
          "{ friend+of+mine:2, hello_there:{ how_are_you?:2, are_you_happy?:`friend+of+mine`+3 } }.hello_there.`are_you_happy?`",
        )).must_equal 5
      end
    end

    describe "A context projection" do
      it "contain the value of each entry (with literal)" do
        _(evaluate("[ {a:1, b:2}, {a:3, b:4} ].a")).must_equal [1, 3]
      end

      it "contain the value of each entry (with variable)" do
        _(evaluate("a.b", a: [{ "b" => 1 }, { "b" => 2 }])).must_equal [1, 2]
      end

      it "contain null if a context doesn't have the given key" do
        _(evaluate("[ {a:1}, {b:2} ].a")).must_equal [1, nil]
        _(evaluate("[ {a:1}, {b:2} ].b")).must_equal [nil, 2]
        _(evaluate("[ {a:1}, {b:2} ].c")).must_equal [nil, nil]
      end
    end

    describe "A context filter" do
      it "access a context entry by key" do
        _(evaluate("[ {a:1, b:2}, {a:3, b:4} ][a > 2]")).must_equal [{ "a" => 3, "b" => 4 }]
      end

      it "access a context entry by the key 'item'" do
        _(evaluate("[ {item:1}, {item:2}, {item:3} ][item >= 2]")).must_equal [{ "item" => 2 }, { "item" => 3 }]
      end

      it "be followed by a path expression" do
        _(evaluate("[{a:1}, {a:2}][1].a")).must_equal 1
      end

      it "be applied to a path expression" do
        _(evaluate("[ {a:1, b:2}, {a:3, b:4} ].a[1]")).must_equal 1
      end

      it "not contain an entry if it doesn't have the given key" do
        _(evaluate("[{x: 1, y: 2}, {x: 3}][y > 1]")).must_equal [{ "x" => 1, "y" => 2 }]
      end

      it "not contain an entry if it the value is null" do
        _(evaluate("[{x: 1}, {x: null}][x > 0]")).must_equal [{ "x" => 1 }]
      end

      it "contain all entries with null value" do
        _(evaluate("[{x: 1}, {x: null}][x = null]")).must_equal [{ "x" => nil }]
      end

      it "contain all entries with null value or missing context entry" do
        # note that a missing entry is equivalent to that entry containing null
        _(evaluate("[{x: 1}, {y: 1}][x = null]")).must_equal [{ "y" => 1 }]
      end
    end
  end
end
