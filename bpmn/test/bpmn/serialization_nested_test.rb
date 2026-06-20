# frozen_string_literal: true

require "test_helper"

module BPMN
  # Regression: restoring an execution parked on a step INSIDE a sub-process must
  # resolve that step by id. Process#element_by_id has to recurse into
  # sub-processes — otherwise the nested execution's step deserialized to nil,
  # silently breaking any sub-process resume with internal waiting nodes.
  describe "Serialization of nested executions" do
    let(:sources) { fixture_source("variable_scope.bpmn") }
    let(:context) { Context.new(sources) }

    it "resolves a step nested inside a sub-process when restoring" do
      execution = context.start(variables: { total: 1, name: "outer" })
      # Sanity: the live tree is parked on the task inside the sub-process.
      _(execution.child_by_step_id("Sub").child_by_step_id("Inner").step.id).must_equal "Inner"

      restored = context.restore(execution.serialize)
      inner = restored.child_by_step_id("Sub").child_by_step_id("Inner")

      _(inner).wont_be_nil
      _(inner.step).wont_be_nil
      _(inner.step.id).must_equal "Inner"
      _(inner.waiting?).must_equal true
    end
  end
end
