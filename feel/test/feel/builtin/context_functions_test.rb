# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: BuiltinContextFunctionsTest
module FEEL
  describe "built-in context functions" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    describe "A get entries function" do
      it "return all entries (when invoked with 'context' argument)" do
        _(evaluate("get entries(context:{foo: 123})")).must_equal [{ "key" => "foo", "value" => 123 }]
      end

      it "return all entries (when invoked with 'm' argument)" do
        _(evaluate(" get entries(m:{foo: 123}) ")).must_equal [{ "key" => "foo", "value" => 123 }]
      end

      it "return empty list if empty" do
        _(evaluate(" get entries({}) ")).must_equal []
      end

      it "return all entries in the same order as in the context" do
        _(evaluate("get entries({a: 1, b: 2, c: 3}).key")).must_equal ["a", "b", "c"]
        _(evaluate('get entries({a: "foo", b: "bar"}).key')).must_equal ["a", "b"]
        _(evaluate("get entries({c: 1, b: 2, a: 3}).key")).must_equal ["c", "b", "a"]
      end
    end

    describe "A get value function" do
      it "return the value" do
        _(evaluate(' get value({foo: 123}, "foo") ')).must_equal 123
      end

      it "return the value when arguments are named 'm' and 'key'" do
        _(evaluate(' get value(m:{foo: 123}, key:"foo") ')).must_equal 123
      end

      it "return the value when arguments are named 'context' and 'key'" do
        _(evaluate(' get value(context:{foo: 123}, key:"foo") ')).must_equal 123
      end

      it "return null if not contains" do
        _(evaluate(' get value({}, "foo") ')).must_be_nil
      end
    end

    describe "A get value with path function" do
      it "return the value when a path is provided" do
        _(evaluate('get value({x: {y: {z:1}}}, ["x", "y", "z"])')).must_equal 1
      end

      it "return a context when a path is provided" do
        _(evaluate('get value({x: {y: {z:1}}}, ["x", "y"]) = {z:1}')).must_equal true
      end

      it "return null if non-existing path is provided" do
        _(evaluate('get value({x: {y: {z:1}}}, ["z"])')).must_be_nil
      end

      it "return null if non-existing nested path is provided" do
        _(evaluate('get value({x: {y: {z:1}}}, ["x", "z"])')).must_be_nil
      end

      it "return null if non-String list of keys is provided" do
        _(evaluate('get value({x: {y: {z:1}}}, ["1", 2])')).must_be_nil
      end

      it "return null if an empty context is provided" do
        _(evaluate('get value({}, ["z"])')).must_be_nil
      end

      it "return null if an empty list is provided as a path" do
        _(evaluate("get value({x: {y: {z:1}}}, [])")).must_be_nil
      end

      it "return a value if named arguments are used" do
        _(evaluate('get value(context: {x: {y: {z:1}}}, keys: ["x"]) = {y: {z:1}}')).must_equal true
      end

      # Adapted: the Scala CustomContext is replaced by a Ruby Hash with
      # Symbol keys (HashWithIndifferentAccess: see test/interop)
      it "return a value from a custom context" do
        _(evaluate('get value(context, ["x", "y"])', context: { x: { y: 1 } })).must_equal 1
      end
    end

    describe "A context put function" do
      it "add an entry to an empty context" do
        _(evaluate(' context put({}, "x", 1) ')).must_equal({ "x" => 1 })
      end

      it "add an entry to an existing context" do
        _(evaluate(' context put({x:1}, "y", 2) ')).must_equal({ "x" => 1, "y" => 2 })
      end

      it "add a new entry at the end of the context" do
        _(evaluate(' get entries(context put({a: 1, b: 2, c: 3}, "d", 4)).key ')).must_equal ["a", "b", "c", "d"]
        _(evaluate(' get entries(context put({c: 1, b: 2, a: 3}, "d", 4)).key ')).must_equal ["c", "b", "a", "d"]
      end

      it "override an entry of an existing context" do
        _(evaluate(' context put({x:1}, "x", 2) ')).must_equal({ "x" => 2 })
      end

      it "override an entry and keep the original order" do
        _(evaluate(' get entries(context put({a: 1, b: 2, c: 3}, "b", 20)).key ')).must_equal ["a", "b", "c"]
        _(evaluate(' get entries(context put({c: 1, b: 2, a: 3}, "c", 10)).key ')).must_equal ["c", "b", "a"]
        _(evaluate(' get entries(context put({c: 1, b: 2, a: 3}, "a", 30)).key ')).must_equal ["c", "b", "a"]
      end

      it "add a context entry to an existing context" do
        _(evaluate(' context put({x:1}, "y", {"z":2}) ')).must_equal({ "x" => 1, "y" => { "z" => 2 } })
      end

      it "add a context entry with null if the value is not present" do
        _(evaluate(' context put({}, "x", notExisting) ')).must_equal({ "x" => nil })
      end

      it "be invoked with named parameters (key)" do
        _(evaluate(' context put(context: {x:1}, key: "y", value: 2) ')).must_equal({ "x" => 1, "y" => 2 })
      end

      it "add a context entry with list argument" do
        _(evaluate(' context put({x:1}, ["y"], 2) ')).must_equal({ "x" => 1, "y" => 2 })
      end

      it "add nested context entry" do
        _(evaluate(' context put({x:1, y:{a:1}}, ["y", "b"], 2) ')).must_equal({ "x" => 1, "y" => { "a" => 1, "b" => 2 } })
        _(evaluate(' context put({x:1, a:{b:{c:1}}}, ["a", "b", "d"], 2) '))
          .must_equal({ "x" => 1, "a" => { "b" => { "c" => 1, "d" => 2 } } })
        _(evaluate(' context put({x:1, a:{b:{c:{d:1}}}}, ["a", "b", "c", "e"], 2) '))
          .must_equal({ "x" => 1, "a" => { "b" => { "c" => { "d" => 1, "e" => 2 } } } })
      end

      it "override nested context entry" do
        _(evaluate(' context put({x:1, y:{a:1}}, ["y", "a"], 2) ')).must_equal({ "x" => 1, "y" => { "a" => 2 } })
        _(evaluate(' context put({x:1, a:{b:{c:1}}}, ["a", "b", "c"], 2) '))
          .must_equal({ "x" => 1, "a" => { "b" => { "c" => 2 } } })
        _(evaluate(' context put({x:1, a:{b:{c:{d:1}}}}, ["a", "b", "c", "d"], 2) '))
          .must_equal({ "x" => 1, "a" => { "b" => { "c" => { "d" => 2 } } } })
      end

      # Adapted: the Scala CustomContext is replaced by a Ruby Hash with
      # Symbol keys (HashWithIndifferentAccess: see test/interop)
      it "override nested context entry from a custom context" do
        vars = { a: { b: 1, c: 2 } }
        _(evaluate(' context put(vars, ["a", "c"], 3) ', vars: vars)).must_equal({ "a" => { "b" => 1, "c" => 3 } })
        _(vars).must_equal({ a: { b: 1, c: 2 } })

        mixed = { "a" => { b: 1, "c" => 2 } }
        _(evaluate(' context put(vars, ["a", "c"], 3) ', vars: mixed)).must_equal({ "a" => { "b" => 1, "c" => 3 } })
        _(mixed["a"]["c"]).must_equal 2
      end

      it "add nested context entry if key doesn't exist" do
        _(evaluate(' context put({x:1}, ["y", "z"], 2) ')).must_equal({ "x" => 1, "y" => { "z" => 2 } })
        _(evaluate(' context put({x:1}, ["a", "b", "c"], 2) ')).must_equal({ "x" => 1, "a" => { "b" => { "c" => 2 } } })
        _(evaluate(' context put({x:1}, ["a", "b", "c", "d"], 2) '))
          .must_equal({ "x" => 1, "a" => { "b" => { "c" => { "d" => 2 } } } })
      end

      it "override nested context entry if existing value is not a context" do
        _(evaluate(' context put({x:1, y:2}, ["y", "z"], 2) ')).must_equal({ "x" => 1, "y" => { "z" => 2 } })
      end

      it "be invoked with named parameters (keys)" do
        _(evaluate(' context put(context: {x:{y:1}}, keys: ["x","y"], value: 2) ')).must_equal({ "x" => { "y" => 2 } })
      end

      it "return null if keys are empty" do
        _(evaluate(" context put({x:1}, [], 2) ")).must_be_nil
      end

      it "return null if keys are null" do
        _(evaluate(" context put({x:1}, null, 2) ")).must_be_nil
      end

      it "return null if keys are not a list of strings" do
        _(evaluate(" context put({x:1}, [1,2,3], 2) ")).must_be_nil
      end
    end

    describe "A put function (deprecated)" do
      it "behave as the context put function" do
        _(evaluate(' put({}, "x", 1) = context put({}, "x", 1) ')).must_equal true
        _(evaluate(' put({x:1}, "y", 2) = context put({x:1}, "y", 2) ')).must_equal true
        _(evaluate(' put({x:1}, "x", 2) = context put({x:1}, "x", 2) ')).must_equal true
      end
    end

    describe "A context merge function" do
      it "return a single empty context" do
        _(evaluate(" context merge({}) ")).must_equal({})
      end

      it "return a single context" do
        _(evaluate(" context merge({x:1}) ")).must_equal({ "x" => 1 })
      end

      it "combine empty contexts" do
        _(evaluate(" context merge({}, {}) ")).must_equal({})
      end

      it "add all entries to an empty context" do
        _(evaluate(" context merge({}, {x:1}) ")).must_equal({ "x" => 1 })
      end

      it "add an entry to an context" do
        _(evaluate(" context merge({x:1}, {y:2}) ")).must_equal({ "x" => 1, "y" => 2 })
      end

      it "add all entries to an context" do
        _(evaluate(" context merge({x:1}, {y:2, z:3}) ")).must_equal({ "x" => 1, "y" => 2, "z" => 3 })
      end

      it "add all entries at the end of the context" do
        _(evaluate(" get entries(context merge({a: 1, b: 2}, {c: 3, d: 4})).key ")).must_equal ["a", "b", "c", "d"]
        _(evaluate(" get entries(context merge({d: 1, c: 2}, {b: 3, a: 4})).key ")).must_equal ["d", "c", "b", "a"]
      end

      it "override an entry of the existing context" do
        _(evaluate(" context merge({x:1}, {x:2}) ")).must_equal({ "x" => 2 })
      end

      it "override entries in order" do
        _(evaluate(" context merge({x:1,y:3,z:1}, {x:2,y:2,z:3}, {x:3,y:1,z:2}) ")).must_equal({ "x" => 3, "y" => 1, "z" => 2 })
      end

      it "override entries and keep the original order" do
        _(evaluate(" get entries(context merge({a: 1, b: 2, c: 3}, {b: 20, d: 4})).key ")).must_equal ["a", "b", "c", "d"]
        _(evaluate(" get entries(context merge({c: 1, b: 2, a: 3}, {b: 20, d: 4})).key ")).must_equal ["c", "b", "a", "d"]
      end

      it "combine three contexts" do
        _(evaluate(" context merge({x:1}, {y:2}, {z:3}) ")).must_equal({ "x" => 1, "y" => 2, "z" => 3 })
      end

      it "add a nested context" do
        _(evaluate(" context merge({x:1}, {y:{z:2}}) ")).must_equal({ "x" => 1, "y" => { "z" => 2 } })
      end

      it "return null if one entry is not a context" do
        _(evaluate(" context merge({}, 1) ")).must_be_nil
      end

      it "be invoked with a list of contexts" do
        _(evaluate(" context merge([{x:1}, {y:2}]) ")).must_equal({ "x" => 1, "y" => 2 })
      end

      it "be invoked with named parameters" do
        _(evaluate(" context merge(contexts: [{x:1}, {y:2}]) ")).must_equal({ "x" => 1, "y" => 2 })
      end
    end

    describe "A put all function (deprecated)" do
      it "behave as the context merge function" do
        _(evaluate(" put all({}) = context merge({}) ")).must_equal true
        _(evaluate(" put all({x:1}) = context merge({x:1}) ")).must_equal true
        _(evaluate(" put all({x:1}, {y:2}) = context merge({x:1}, {y:2}) ")).must_equal true
        _(evaluate(" put all({x:1,y:3,z:1}, {x:2,y:2,z:3}, {x:3,y:1,z:2}) = context merge({x:1,y:3,z:1}, {x:2,y:2,z:3}, {x:3,y:1,z:2}) ")).must_equal true
        _(evaluate(" put all({x:1}, {y:{z:2}}) = context merge({x:1}, {y:{z:2}}) ")).must_equal true
      end
    end

    describe "A context function" do
      it "return an empty context" do
        _(evaluate(" context([]) ")).must_equal({})
      end

      it "return a context with one entry" do
        _(evaluate(' context([{"key":"a", "value":1}]) ')).must_equal({ "a" => 1 })
      end

      it "return a context with multiple entries" do
        _(evaluate(' context([{"key":"a", "value":1}, {"key":"b", "value":true}, {"key":"c", "value":"ok"}]) '))
          .must_equal({ "a" => 1, "b" => true, "c" => "ok" })
      end

      it "return a context with a nested list" do
        _(evaluate(' context([{"key":"a", "value":[1,2,3]}]) ')).must_equal({ "a" => [1, 2, 3] })
      end

      it "return a context with a nested context" do
        _(evaluate(' context([{"key":"a", "value": {x:1} }]) ')).must_equal({ "a" => { "x" => 1 } })
      end

      it "return a context with the same order as the given entries" do
        _(evaluate(<<~FEEL)).must_equal ["a", "b", "c"]
          get entries(context([
               {"key":"a","value":1},
               {"key":"b","value":2},
               {"key":"c","value":3}
               ])).key
        FEEL
        _(evaluate(<<~FEEL)).must_equal ["c", "b", "a"]
          get entries(context([
               {"key":"c","value":1},
               {"key":"b","value":2},
               {"key":"a","value":3}
               ])).key
        FEEL
      end

      it "override entries in order" do
        _(evaluate(' context([{"key":"a", "value":1}, {"key":"a", "value":3}, {"key":"a", "value":2}]) ')).must_equal({ "a" => 2 })
      end

      it "be the reverse operation to `get entries()`" do
        _(evaluate(" context(get entries({})) = {} ")).must_equal true
        _(evaluate(" context(get entries({a:1})) = {a:1} ")).must_equal true
        _(evaluate(" context(get entries({a:1,b:2})) = {a:1, b:2} ")).must_equal true
        _(evaluate(' context(get entries({a:1,b:2})[key="a"]) = {a:1} ')).must_equal true
      end

      it "return null if one entry is not a context" do
        _(evaluate(' context([{"key":"a", "value":1}, "x"]) ')).must_be_nil
      end

      it "return null if one entry doesn't contain a key" do
        _(evaluate(' context([{"key":"a", "value":1}, {"value":2}]) ')).must_be_nil
      end

      it "return null if one entry doesn't contain a value" do
        _(evaluate(' context([{"key":"a", "value":1}, {"key":"b"}]) ')).must_be_nil
      end

      it "return null if the key of one entry is not a string" do
        _(evaluate(' context([{"key":"a", "value":1}, {"key":2, "value":2}]) ')).must_be_nil
      end

      # Adapted: the Scala CustomContext is replaced by Ruby Hashes with
      # Symbol keys (HashWithIndifferentAccess: see test/interop)
      it "return a context with entries from a custom context" do
        _(evaluate("context(list)", list: [{ key: "a", value: 1 }])).must_equal({ "a" => 1 })
        _(evaluate("context(list)", list: [{ "key" => "a", value: 1 }])).must_equal({ "a" => 1 })
      end
    end
  end
end
