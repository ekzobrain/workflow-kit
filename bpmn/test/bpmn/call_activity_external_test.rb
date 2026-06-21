# frozen_string_literal: true

require "test_helper"

module BPMN

  # Call activity in the separate-instance model: the called process is not in the
  # engine's context, so the activity waits and is completed by an external signal
  # (the finished child instance's variables). Variable propagation follows
  # propagateAllChildVariables + output mappings.
  describe "Call Activity (external signal)" do
    describe "propagateAllChildVariables = true" do
      let(:context) { BPMN.new(fixture_source("call_activity_external.bpmn")) }

      it "waits at the call activity, then completes when signaled, propagating all child variables" do
        execution = context.start
        call = execution.child_by_step_id("Call")

        _(call.waiting?).must_equal true
        _(execution.ended?).must_equal false

        call.signal({ "result" => 42, "extra" => "x" })

        _(call.ended?).must_equal true
        _(execution.completed?).must_equal true
        _(execution.variables["result"]).must_equal 42
        _(execution.variables["extra"]).must_equal "x"
      end
    end

    describe "propagateAllChildVariables = false with an output mapping" do
      let(:context) { BPMN.new(fixture_source("call_activity_external_mapped.bpmn")) }

      it "propagates only the output-mapped variable, discarding the rest" do
        execution = context.start
        call = execution.child_by_step_id("Call")

        _(call.waiting?).must_equal true

        call.signal({ "result" => 42, "secret" => "leak" })

        _(execution.completed?).must_equal true
        _(execution.variables["outcome"]).must_equal 42      # the output mapping
        _(execution.variables["result"]).must_be_nil         # raw child var discarded
        _(execution.variables["secret"]).must_be_nil         # raw child var discarded
      end
    end
  end
end
