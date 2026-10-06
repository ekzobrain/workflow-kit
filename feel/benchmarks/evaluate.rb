# frozen_string_literal: true

# Benchmarks of evaluating small FEEL expressions many times with different
# variables.
#
#   cd feel && bundle exec ruby benchmarks/evaluate.rb [iterations]

require "bundler/setup"
require_relative "../lib/feel"

ITERATIONS = (ARGV[0] || 20_000).to_i

EXPRESSIONS = {
  "a + b" => ->(i) { { a: i, b: 2 } },
  "string(a)" => ->(i) { { a: i } },
  "person.age >= 18" => ->(i) { { person: { age: i % 40 } } },
  'if a > 10 then "high" else "low"' => ->(i) { { a: i % 20 } },
  "sum(items)" => ->(i) { { items: [i, 2, 3] } },
  "a * 1.5" => ->(i) { { a: i } },
}.freeze

UNARY_TESTS = {
  "< 10" => ->(i) { i % 20 },
  '"A", "B"' => ->(i) { i.even? ? "A" : "C" },
  "[1..5]" => ->(i) { i % 10 },
}.freeze

def measure(label)
  GC.start
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { |i| yield i }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  printf("  %-38s %8.2f µs/op %10.0f ops/s\n", label, elapsed / ITERATIONS * 1_000_000, ITERATIONS / elapsed)
end

puts "Ruby #{RUBY_VERSION}, #{ITERATIONS} iterations"

EXPRESSIONS.each do |text, variables|
  puts "\n#{text}"
  measure("FEEL.evaluate") { |i| FEEL.evaluate(text, variables: variables.call(i)) }

  expression = FEEL.compile(text)
  measure("FEEL.compile(...).evaluate") { |i| expression.evaluate(variables.call(i)) }

  measure("  parse only (uncached)") { FEEL::Parser.parse(text) }
  measure("  build root scope only") { |i| FEEL::RootScope.build(variables.call(i)) }
  context = FEEL::RootScope.build(variables.call(1))
  measure("  tree.eval only (interpreted)") { expression.tree.eval(context) }
  measure("  tree.compiled only (closures)") { expression.tree.compiled.call(context) }
end

UNARY_TESTS.each do |text, input|
  puts "\nunary tests: #{text}"
  measure("FEEL.test") { |i| FEEL.test(input.call(i), text) }

  tests = FEEL.compile_test(text)
  measure("FEEL.compile_test(...).test") { |i| tests.test(input.call(i)) }
end
