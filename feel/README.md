# FEEL

A light-weight FEEL expression evaluator ruby gem.

This gem implements a subset of FEEL (Friendly Enough Expression Language) as defined in the [DMN 1.3 specification](https://www.omg.org/spec/DMN/1.3/PDF) with some additional extensions.

FEEL expressions are parsed into an abstract syntax tree (AST) and then evaluated in a context. The context is a hash of variables and functions to be resolved inside the expression.

Expressions are safe, side-effect free, and deterministic. They are ideal for capturing business logic for storage in a database or embedded in DMN, BPMN, or Form documents for execution in a workflow engine.

This project was inspired by these excellent libraries:

- [feelin](https://github.com/nikku/feelin)
- [dmn-eval-js](https://github.com/mineko-io/dmn-eval-js)

## Usage

To evaluate an expression:

```ruby
FEEL.evaluate('"👋 Hello " + name', variables: { name: "World" })
# => "👋 Hello World"
```

A slightly more complex example:

```ruby
variables = {
  person: {
    name: "Eric",
    age: 59,
  }
}
FEEL.evaluate('if person.age >= 18 then "adult" else "minor"', variables:)
# => "adult"
```

Strict mode will raise an exception if an expression references a variable that is not defined in the context.

```ruby
FEEL.configure do |config|
  config.strict = true
end

LiteralExpression.new(text: "person.agx").evaluate({ "person": { "name": "Bob", "age": 32 } })
# => raises EvaluationError("Identifier person.agx not found. Did you mean person.age?")
```

Calling a built-in function:

```ruby
FEEL.evaluate('sum([1, 2, 3])')
# => 6
```

Calling a user-defined function:

```ruby
FEEL.config.functions = {
  "reverse": ->(s) { s.reverse }
}
FEEL.evaluate('reverse("Hello World!")')
# => "!dlroW olleH"
```

Iterating, filtering and testing lists:

```ruby
FEEL.evaluate("for i in 1..3 return i * i")
# => [1, 4, 9]

FEEL.evaluate("some order in orders satisfies order.total > 100", variables: { orders: [{ total: 50 }, { total: 150 }] })
# => true

FEEL.evaluate("orders[total > 100].id", variables: { orders: [{ id: 1, total: 50 }, { id: 2, total: 150 }] })
# => [2]

FEEL.evaluate("[1, 2, 3][-1]")
# => 3
```

Boolean logic (with three-valued semantics for `null`), `between`, `in` and `instance of`:

```ruby
FEEL.evaluate("age >= 18 and country in (\"NL\", \"BE\")", variables: { age: 21, country: "NL" })
# => true

FEEL.evaluate("score between 1 and 10 or score = null", variables: { score: 5 })
# => true

FEEL.evaluate("x instance of number", variables: { x: 42 })
# => true
```

Defining functions:

```ruby
FEEL.evaluate("{ square: function(x) x * x, result: square(4) }.result")
# => 16

FEEL.evaluate("sort([3, 1, 2], function(x, y) x > y)")
# => [3, 2, 1]

FEEL.evaluate("{ sub: function(a, b) a - b }.sub(b: 1, a: 5)")
# => 4
```

Comments:

```ruby
FEEL.evaluate(<<~FEEL)
  /* compute the total */
  price * quantity // without taxes
FEEL
```

Names can't contain whitespace or reserved words (`and`, `or`, `in`, `then`, ...) unless they are escaped with backticks, e.g. `` `first name` ``. Names with whitespace are allowed for function names, parameter names and context keys.

To evaluate a unary tests:

```ruby
FEEL.test(3, '<= 10, > 50'))
# => true
```

```ruby
FEEL.test("Eric", '"Bob", "Holly", "Eric"')
# => true
```

A unary test can also be any expression. If it uses the input value `?`, the result of the expression is the result of the test. Otherwise, the test passes if the expression evaluates to `true`, to a list that contains the input value or to a value equal to the input value:

```ruby
FEEL.test("Garbage cart pickup", 'starts with(?, "Garbage")')
# => true

FEEL.test(5, "? > limit and odd(?)", variables: { limit: 3 })
# => true

FEEL.test("NL", "countries", variables: { countries: ["NL", "BE"] })
# => true
```

To get a list of variables or functions used in an expression:

```ruby
LiteralExpression.new(text: 'person.first_name + " " + person.last_name').variable_names
# => ["person.age, person.last_name"]
```

```ruby
LiteralExpression.new(text: 'sum([1, 2, 3])').function_names
# => ["sum"]
```

```ruby
UnaryTests.new(text: '> speed - speed_limit').variable_names
# => ["speed, speed_limit"]
```

### Compiling and caching expressions

Parsing an expression is much more expensive than evaluating it. `FEEL.compile` parses an expression once and returns an object that can be evaluated many times with different variables:

```ruby
expression = FEEL.compile("a + b")
expression.evaluate(a: 1, b: 2)   # => 3
expression.evaluate(a: 10, b: 20) # => 30

tests = FEEL.compile_test("< 10, > 50")
tests.test(5)  # => true
tests.test(20) # => false
```

`FEEL.evaluate` and `FEEL.test` use the same cache, so repeatedly evaluating the same text is cheap too. The cache is a thread-safe LRU cache keyed by the expression text; compiled expressions can be shared between threads. Its size is configurable (`0` disables it):

```ruby
FEEL.configure do |config|
  config.expression_cache_size = 10_000 # default: 1_000
end

FEEL.clear_expression_cache
```

A compiled expression doesn't depend on the variables: names with whitespace or operators (e.g. `` `first name` ``, `` `a+b` ``) must be escaped with backticks, so `a+b` always means an addition, whatever the context contains. Variables take precedence over custom functions (`config.functions`), which take precedence over built-in functions.

Benchmarks of small expressions are in `benchmarks/evaluate.rb`:

```bash
bundle exec ruby benchmarks/evaluate.rb
```

## Supported Features

### Data Types

- [x] Boolean (true, false)
- [x] Number (integer, decimal)
- [x] String (single and double quoted)
- [x] Date, Time, Duration (ISO 8601)
- [x] List (array)
- [x] Context (hash)

### Expressions

- [x] Literal
- [x] Path
- [x] Arithmetic
- [x] Comparison
- [x] Function Invocation
- [x] Positional Parameters
- [x] Named Parameters
- [x] If Expression
- [x] For Expression
- [x] Quantified Expression (`some`, `every`)
- [x] Filter Expression
- [x] Disjunction
- [x] Conjunction
- [x] Between
- [x] In
- [x] Instance Of
- [x] Function Definition

### Unary Tests

- [x] Comparison
- [x] Interval/Range (inclusive and exclusive)
- [x] Disjunction
- [x] Negation
- [x] Expression

### Built-in Functions

- [x] Conversion: `string`, `number`, `from json`, `to json`
- [x] Boolean: `not`, `is defined`, `get or else`, `assert`
- [x] String: `substring`, `substring before`, `substring after`, `string length`, `upper case`, `lower case`, `contains`, `starts with`, `ends with`, `matches`, `replace`, `split`, `extract`, `trim`, `strip`, `uuid`, `to base64`, `from base64`, `is blank`
- [x] Numeric: `decimal`, `floor`, `ceiling`, `round up`, `round down`, `round half up`, `round half down`, `abs`, `modulo`, `sqrt`, `log`, `exp`, `odd`, `even`, `random number`
- [x] List: `list contains`, `count`, `min`, `max`, `sum`, `product`, `mean`, `median`, `stddev`, `mode`, `and`, `all`, `or`, `any`, `sublist`, `append`, `concatenate`, `insert before`, `remove`, `reverse`, `index of`, `union`, `distinct values`, `duplicate values`, `flatten`, `sort`, `string join`, `is empty`, `partition`
- [x] Context: `get value`, `get entries`, `context put`, `put`, `context merge`, `put all`, `context`
- [x] Temporal: `date`, `time`, `date and time`, `duration`, `years and months duration`, `now`, `today`, `day of week`, `day of year`, `week of year`, `month of year`, `last day of month`
- [x] Range: `before`, `after`, `meets`, `met by`, `overlaps`, `overlaps before`, `overlaps after`, `finishes`, `finished by`, `includes`, `during`, `starts`, `started by`, `coincides`

### Values

FEEL values are represented by these Ruby values (the results of `FEEL.evaluate`):

| FEEL | Ruby |
|---|---|
| number | `Integer`, `Float` (decimal literals are computed exactly with `BigDecimal` and returned as `Float`) |
| string, boolean, null | `String`, `true`/`false`, `nil` |
| list, context | `Array`, `Hash` (String keys) |
| date | `Date` |
| time | `FEEL::LocalTime` (no offset), `FEEL::ZonedTime` (with offset or zone id) |
| date and time | `FEEL::LocalDateTime` (no offset), `Time` (with offset), `Time` with a `TZInfo::Timezone` as zone (with zone id, e.g. `@Europe/Berlin`) |
| years and months duration, days and time duration | `FEEL::Duration` |
| range | `FEEL::Range` |
| function | `FEEL::Function`, `Proc` |

Variables can be given as these values or as other Ruby values: `DateTime`, and, if the application uses ActiveSupport, `ActiveSupport::TimeWithZone`, `ActiveSupport::Duration` and `HashWithIndifferentAccess`. Hash keys can be Strings or Symbols. The results of an evaluation can be passed as variables to the next one.

`FEEL::Duration` can be created and converted in Ruby:

```ruby
FEEL::Duration.parse("P1Y2M")         # => #<FEEL::Duration P1Y2M>
FEEL::Duration.hours(26).to_s          # => "P1DT2H"
FEEL::Duration.days(1).to_active_support # => 1 day (requires ActiveSupport)
```

`now()` and `today()` use the zone `config.time_zone` (e.g. `"Europe/Berlin"`). If it is not set, `Time.zone` of ActiveSupport is used if available, else the system zone.

### JSON and serialization

`FEEL.to_json` (and `FEEL.as_json`) converts a value to plain JSON, with temporal values as ISO 8601 strings, like the FEEL function `to json()`. The FEEL value classes also implement `to_json`. The types are lost:

```ruby
result = FEEL.evaluate('{due: date("2020-01-01"), wait: duration("P2D")}')
FEEL.to_json(result) # => '{"due":"2020-01-01","wait":"P2D"}'
```

`FEEL.serialize` and `FEEL.deserialize` keep the types. Values that JSON can't represent are tagged with the key `"$feel"`, so they can be stored (e.g. as the state of a process) and restored to be used in the next evaluation:

```ruby
data = FEEL.serialize(result)
# => {"due"=>{"$feel"=>"date", "value"=>"2020-01-01"}, "wait"=>{"$feel"=>"duration", "value"=>"P2D"}}
variables = FEEL.deserialize(data.to_json)
FEEL.evaluate("due + wait", variables: variables) # => #<Date: 2020-01-03>
```

| FEEL type | Serialized |
|---|---|
| date | `{"$feel": "date", "value": "2020-01-01"}` |
| time | `{"$feel": "time", "value": "10:30:00+01:00", "zone": "Europe/Paris"}` (`zone` only for a zone id) |
| date and time | `{"$feel": "date and time", "value": "2020-07-01T10:30:00@Europe/Berlin", "offset": "+02:00"}` (`offset` only for a zone id) |
| durations | `{"$feel": "duration", "value": "P1Y2M"}` |
| range | `{"$feel": "range", "start": ..., "end": ..., "start included": true, "end included": false}` |

A context that contains the key `"$feel"` itself is escaped as `{"$feel": "context", "value": {...}}`. Functions can't be serialized (`FEEL::SerializationError`).

### Compatibility

The behavior is verified against the test suite of [feel-scala](https://github.com/camunda/feel-scala) (Camunda), which is ported to `test/feel/interpreter` and `test/feel/builtin`. Only the cases specific to the JVM API (value mappers, Java beans, script engine) are not applicable.

### Comments

- [x] Single-line
- [x] Multi-line

## Installation

Execute:

```bash
$ bundle add "feel"
```

Or install it directly:

```bash
$ gem install feel
```

The gem doesn't depend on Rails or ActiveSupport. Time zones use the [tzinfo](https://github.com/tzinfo/tzinfo) gem and the zone database of the system; on systems without one (e.g. Windows), also add the `tzinfo-data` gem.

### Setup

```bash
$ git clone ...
$ bin/setup
$ cd feel
$ bin/rake
$ bin/guard
```

## Development

[Treetop Doumentation](https://cjheath.github.io/treetop/syntactic_recognition.html) is a good place to start learning about Treetop.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Developed by [Connected Bits](http://www.connectedbits.com)
