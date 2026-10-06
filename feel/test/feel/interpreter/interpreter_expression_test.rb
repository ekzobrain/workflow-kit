# frozen_string_literal: true

require "test_helper"

# Ported from feel-scala: InterpreterExpressionTest
module FEEL
  describe "interpreter expression" do
    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    def valid?(expression)
      LiteralExpression.new(text: expression).valid?
    end

    describe "An expression" do
      it "should be an if-then-else (with parentheses)" do
        exp = ' if (x < 5) then "low" else "high" '

        _(evaluate(exp, x: 2)).must_equal "low"
        _(evaluate(exp, x: 7)).must_equal "high"

        _(evaluate(exp, x: "foo")).must_equal "high"
      end

      it "should be an if-then-else (without parentheses)" do
        _(evaluate("if x < 5 then 1 else 2", x: 2)).must_equal 1
      end

      it "should be an if-then-else (with literal)" do
        _(evaluate("if true then 1 else 2")).must_equal 1
      end

      it "should be an if-then-else (with path)" do
        _(evaluate("if {a: true}.a then 1 else 2")).must_equal 1
      end

      it "should be an if-then-else (with filter)" do
        _(evaluate("if [true][1] then 1 else 2")).must_equal 1
      end

      it "should be an if-then-else (with conjunction)" do
        _(evaluate("if true and true then 1 else 2")).must_equal 1
      end

      it "should be an if-then-else (with disjunction)" do
        _(evaluate("if false or true then 1 else 2")).must_equal 1
      end

      it "should be an if-then-else (with in-test)" do
        _(evaluate("if 1 in < 5 then 1 else 2")).must_equal 1
      end

      it "should be an if-then-else (with instance of)" do
        _(evaluate("if 1 instance of number then 1 else 2")).must_equal 1
      end

      it "should be an if-then-else (with variable and function call -> then)" do
        _(evaluate("if 7 > var then flatten(xs) else []", xs: [1, 2], var: 3)).must_equal [1, 2]
      end

      it "should be an if-then-else (with variable and function call -> else)" do
        _(evaluate("if false then var else flatten(xs)", xs: [1, 2], var: 3)).must_equal [1, 2]
      end

      it "should be a simple positive unary test" do
        _(evaluate("< 3", "?": 2)).must_equal true

        _(evaluate("(2 .. 4)", "?": 5)).must_equal false
      end

      it "should be an instance of (literal)" do
        _(evaluate("x instance of number", x: 1)).must_equal true
        _(evaluate("x instance of number", x: "NaN")).must_equal false

        _(evaluate("x instance of boolean", x: true)).must_equal true
        _(evaluate("x instance of boolean", x: 0)).must_equal false

        _(evaluate("x instance of string", x: "yes")).must_equal true
        _(evaluate("x instance of string", x: 0)).must_equal false
      end

      it "should be an instance of (duration)" do
        _(evaluate('duration("P3M") instance of years and months duration')).must_equal true
        _(evaluate('duration("PT4H") instance of days and time duration')).must_equal true
        _(evaluate("null instance of years and months duration")).must_equal false
        _(evaluate("null instance of days and time duration")).must_equal false
      end

      it "should be an instance of (date)" do
        _(evaluate('date("2023-03-07") instance of date')).must_equal true
        _(evaluate(' @"2023-03-07" instance of date')).must_equal true
        _(evaluate("1 instance of date")).must_equal false
      end

      it "should be an instance of (time)" do
        _(evaluate('time("11:27:00") instance of time')).must_equal true
        _(evaluate(' @"11:27:00" instance of time')).must_equal true
        _(evaluate("1 instance of time")).must_equal false
      end

      it "should be an instance of (date and time)" do
        _(evaluate('date and time("2023-03-07T11:27:00") instance of date and time')).must_equal true

        _(evaluate(' @"2023-03-07T11:27:00" instance of date and time')).must_equal true
        _(evaluate("1 instance of date and time")).must_equal false
      end

      it "should be an instance of (list)" do
        _(evaluate("[1,2,3] instance of list")).must_equal true
        _(evaluate("[] instance of list")).must_equal true
        _(evaluate("1 instance of list")).must_equal false
      end

      it "should be an instance of (context)" do
        _(evaluate("{x:1} instance of context")).must_equal true
        _(evaluate("{} instance of context")).must_equal true
        _(evaluate("1 instance of context")).must_equal false
      end

      it "should be an instance of (multiplication)" do
        _(evaluate("2 * 3 instance of number")).must_equal true
      end

      it "should be an instance of (function definition)" do
        _(evaluate(' (function() "foo") instance of function ')).must_equal true
        _(evaluate("1 instance of function")).must_equal false
      end

      it "should be a instance of Any should always pass" do
        _(evaluate("x instance of Any", x: "yes")).must_equal true
        _(evaluate("x instance of Any", x: 1)).must_equal true
        _(evaluate("x instance of Any", x: true)).must_equal true
        _(evaluate("x instance of Any", x: nil)).must_equal false
      end

      it "should be an escaped identifier" do
        # regular identifier
        _(evaluate(" `x` ", x: "foo")).must_equal "foo"
        # with whitespace
        _(evaluate(" `a b` ", "a b": "foo")).must_equal "foo"
        # with operator
        _(evaluate(" `a-b` ", "a-b": 3)).must_equal 3
      end

      it "should contains parentheses" do
        _(evaluate("(1 + 2)")).must_equal 3
        _(evaluate("(1 + 2) + 3")).must_equal 6
        _(evaluate("1 + (2 + 3)")).must_equal 6

        _(evaluate("([1,2,3])[1]")).must_equal 1
        _(evaluate("({x:1}).x")).must_equal 1
        _(evaluate("{x:(1)}.x")).must_equal 1

        _(evaluate("[1,2,3,4][(1)]")).must_equal 1
      end

      it "should contain parentheses in a context literal" do
        context = { xs: [1, 2, 3] }

        _(evaluate("{x:(xs[1])}.x", context)).must_equal 1
        _(evaluate("{x:(xs)[1]}.x", context)).must_equal 1
        _(evaluate("{x:(xs)}.x", context)).must_equal [1, 2, 3]
      end

      it "should contains nested filter expressions" do
        _(evaluate("[1,2,3,4][item > 2][1]")).must_equal 3
        _(evaluate("([1,2,3,4])[item > 2][1]")).must_equal 3
        _(evaluate("([1,2,3,4][item > 2])[1]")).must_equal 3
      end

      it "should contains nested path expressions" do
        _(evaluate("{x:{y:1}}.x.y")).must_equal 1
        _(evaluate("{x:{y:{z:1}}}.x.y.z")).must_equal 1

        _(evaluate("({x:{y:{z:1}}}).x.y.z")).must_equal 1
        _(evaluate("({x:{y:{z:1}}}.x).y.z")).must_equal 1
        _(evaluate("({x:{y:{z:1}}}.x.y).z")).must_equal 1
      end

      it "should contains nested filter and path expressions" do
        _(evaluate("[{x:{y:1}},{x:{y:2}},{x:{y:3}}].x.y[2]")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}]).x.y[2]")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}].x).y[2]")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}].x.y)[2]")).must_equal 2

        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}]).x[2].y")).must_equal 2
        _(evaluate("([{x:{y:1}},{x:{y:2}},{x:{y:3}}])[2].x.y")).must_equal 2

        _(evaluate("[{x:[1,2]},{x:[3,4]},{x:[5,6]}][2].x[1]")).must_equal 3

        _(evaluate("([{x:[1,2]},{x:[3,4]},{x:[5,6]}]).x[2][1]")).must_equal 3
        _(evaluate("([{x:[1,2]},{x:[3,4]},{x:[5,6]}].x)[2][1]")).must_equal 3
        _(evaluate("([{x:[1,2]},{x:[3,4]},{x:[5,6]}].x[2])[1]")).must_equal 3
      end
    end

    describe "Null" do
      it "should compare to null" do
        _(evaluate("null = null")).must_equal true
        _(evaluate("null != null")).must_equal false
      end

      it "should compare to nullable variable" do
        _(evaluate("null = x", x: nil)).must_equal true
        _(evaluate("null = x", x: 1)).must_equal false

        _(evaluate("null != x", x: nil)).must_equal false
        _(evaluate("null != x", x: 1)).must_equal true
      end

      it "should compare to nullable context entry" do
        _(evaluate("null = {x: null}.x")).must_equal true
        _(evaluate("null = {x: 1}.x")).must_equal false

        _(evaluate("null != {x: null}.x")).must_equal false
        _(evaluate("null != {x: 1}.x")).must_equal true
      end

      it "should compare to not existing variable" do
        _(evaluate("null = x")).must_equal true
        _(evaluate("null = x.y")).must_equal true

        _(evaluate("x = null")).must_equal true
        _(evaluate("x.y = null")).must_equal true
      end

      it "should compare to not existing context entry" do
        _(evaluate("null = {}.x")).must_equal true
        _(evaluate("null = {x: null}.x.y")).must_equal true

        _(evaluate("{}.x = null")).must_equal true
        _(evaluate("{x: null}.x.y = null")).must_equal true
      end
    end

    describe "A variable name" do
      it "should not be a key-word" do
        _(valid?("{ null: 1 }.null")).must_equal false
        _(valid?("{ true: 1}.true")).must_equal false
        _(valid?("{ false: 1}.false")).must_equal false
        _(valid?("function")).must_equal false
        _(valid?("in")).must_equal false
        _(valid?("return")).must_equal false
        _(valid?("then")).must_equal false
        _(valid?("else")).must_equal false
        _(valid?("satisfies")).must_equal false
        _(valid?("and")).must_equal false
        _(valid?("or")).must_equal false
      end

      # Ignored as these keywords are not listed as reserved keywords yet
      it "should not be a key-word (ignored)" do
        skip "ignored in feel-scala: these keywords are not listed as reserved keywords yet"
        _(valid?("some")).must_equal false
        _(valid?("every")).must_equal false
        _(valid?("if")).must_equal false
        _(valid?("for")).must_equal false
        _(valid?("between")).must_equal false
        _(valid?("instance")).must_equal false
        _(valid?("of")).must_equal false
        _(valid?("not")).must_equal false
      end

      %w[
        something
        everything
        often
        orY
        andX
        trueX
        falseY
        nullOrString
        functionX
        instances
        forDev
        ifImportant
        thenX
        elseY
        betweenXandY
        notThis
        inside
        durationX
        dateX
        timeX
        inX
        in1
      ].each do |variable_name|
        it "should contain a key-word (#{variable_name})" do
          _(evaluate("#{variable_name} = true", variable_name => true)).must_equal true
        end
      end
    end

    describe "A comment" do
      it "should be written as end of line comments //" do
        _(evaluate(" [1,2,3][1] // the first item ")).must_equal 1
      end

      it "should be written as trailing comments /* .. */" do
        _(evaluate(" [1,2,3][1] /* the first item */ ")).must_equal 1
      end

      it "should be written as single line comments /* .. */" do
        _(evaluate(<<~FEEL)).must_equal 1

          /* the first item */
          [1,2,3][1]
        FEEL
      end

      it "should be written as block comments /* .. */" do
        _(evaluate(<<~FEEL)).must_equal 1

          /*
           * the first item
           */
          [1,2,3][1]
        FEEL
      end
    end

    describe "The special variable '?' (input value)" do
      it "should be available in an unary-test" do
        _(evaluate("5 in ? < 10")).must_equal true
        _(evaluate("5 in ? < 3")).must_equal false
      end

      it "should not be available outside an unary-test" do
        # feel-scala fails the evaluation, the Ruby engine returns null
        _(evaluate("? < 10")).must_be_nil
      end
    end

    # FEEL-specific whitespace characters from the DMN specification
    WHITESPACE_CHARS = %W[
      \u0009   \u0085     ᠎
              ​         　 ﻿ \u000A \u000B
      \u000C \u000D
    ].freeze

    describe "A space character" do
      it "should be ignored before of a literal" do
        WHITESPACE_CHARS.each do |ws|
          _(evaluate("#{ws}1")).must_equal 1, "with #{ws.inspect}"
        end
      end

      it "should be ignored after of a literal" do
        WHITESPACE_CHARS.each do |ws|
          _(evaluate("1#{ws}")).must_equal 1, "with #{ws.inspect}"
        end
      end

      it "should be ignored between a math operation" do
        WHITESPACE_CHARS.each do |ws|
          _(evaluate("#{ws}1+2")).must_equal 3, "with #{ws.inspect}"
          _(evaluate("1#{ws}+2")).must_equal 3, "with #{ws.inspect}"
          _(evaluate("1+#{ws}2")).must_equal 3, "with #{ws.inspect}"
          _(evaluate("1+2#{ws}")).must_equal 3, "with #{ws.inspect}"
        end
      end

      it "should be ignored between a comparison" do
        WHITESPACE_CHARS.each do |ws|
          _(evaluate("#{ws}1<2")).must_equal true, "with #{ws.inspect}"
          _(evaluate("1#{ws}<2")).must_equal true, "with #{ws.inspect}"
          _(evaluate("1<#{ws}2")).must_equal true, "with #{ws.inspect}"
          _(evaluate("1<2#{ws}")).must_equal true, "with #{ws.inspect}"
        end
      end

      it "should be ignored inside a context literal" do
        WHITESPACE_CHARS.each do |ws|
          _(evaluate("{#{ws}x:1}")).must_equal({ "x" => 1 }, "with #{ws.inspect}")
          _(evaluate("{x#{ws}:1}")).must_equal({ "x" => 1 }, "with #{ws.inspect}")
          _(evaluate("{x:#{ws}1}")).must_equal({ "x" => 1 }, "with #{ws.inspect}")
          _(evaluate("{x:1#{ws}}")).must_equal({ "x" => 1 }, "with #{ws.inspect}")
        end
      end

      it "should be ignored inside a for loop" do
        WHITESPACE_CHARS.each do |ws|
          _(evaluate("for#{ws}x in [1] return x")).must_equal [1], "with #{ws.inspect}"
          _(evaluate("for x#{ws}in [1] return x")).must_equal [1], "with #{ws.inspect}"
          _(evaluate("for x in#{ws}[1] return x")).must_equal [1], "with #{ws.inspect}"
          _(evaluate("for x in [1]#{ws}return x")).must_equal [1], "with #{ws.inspect}"
          _(evaluate("for x in [1] return#{ws}x")).must_equal [1], "with #{ws.inspect}"
        end
      end

      it "should be ignored inside a some/every operation" do
        WHITESPACE_CHARS.each do |ws|
          _(evaluate("some#{ws}x in [1] satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("some x#{ws}in [1] satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("some x in#{ws}[1] satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("some x in [1]#{ws}satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("some x in [1] satisfies#{ws}odd(x)")).must_equal true, "with #{ws.inspect}"

          _(evaluate("every#{ws}x in [1] satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("every x#{ws}in [1] satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("every x in#{ws}[1] satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("every x in [1]#{ws}satisfies odd(x)")).must_equal true, "with #{ws.inspect}"
          _(evaluate("every x in [1] satisfies#{ws}odd(x)")).must_equal true, "with #{ws.inspect}"
        end
      end
    end
  end
end
