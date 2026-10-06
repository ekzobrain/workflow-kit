# frozen_string_literal: true

GEM_ROOT = File.join(File.dirname(__FILE__), "..")

require "minitest/autorun"
require "minitest/reporters"
require "minitest/spec"
require "minitest/focus"
require "pry"
require_relative "../lib/feel"

# The gem must not depend on ActiveSupport (it is only accepted as input, see
# test/interop, which runs in a separate process).
raise "ActiveSupport must not be loaded by the FEEL tests" if defined?(ActiveSupport) && !ENV["FEEL_INTEROP"]

Minitest::Reporters.use!(
  Minitest::Reporters::ProgressReporter.new(color: true),
    ENV,
    Minitest.backtrace_filter,
)


class Minitest::Spec
  before :each do
    FEEL.config.functions = {}
    FEEL.config.strict = false
    FEEL.config.time_zone = nil
  end

  # Pins the current time (Time.now) during the block.
  def travel_to(time)
    original = Time.method(:now)
    Time.define_singleton_method(:now) { time }
    yield
  ensure
    Time.define_singleton_method(:now, original)
  end

  after :each do
  end

  def file_fixture(filename)
    Pathname.new(File.join(GEM_ROOT, "/test/fixtures/files", filename))
  end

  def fixture_source(filename)
    file_fixture(filename).read
  end

  def eval(expression, context: {})
    FEEL::Parser.new.evaluate(expression, context: context)
  end

  def unary(context, expression)
    FEEL::Parser.new.unary_test(expression, context: context)
  end
end
