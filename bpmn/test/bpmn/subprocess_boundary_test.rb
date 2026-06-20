# frozen_string_literal: true

require "test_helper"

module BPMN

  # Boundary events on a sub-process, plus error/escalation bubbling: an
  # error/escalation raised inside the sub-process is caught by the interrupting
  # boundary on the sub-process, which terminates it and takes the boundary path.
  describe "Sub-process boundary" do
    describe "error" do
      let(:context) { BPMN.new(fixture_source("subprocess_boundary_error.bpmn")) }

      it "parses a boundary event attached to a sub-process" do
        sub = context.process_by_id("ErrorBubble").element_by_id("Sub")
        _(sub.attachments.map(&:id)).must_equal ["OnError"]
      end

      it "bubbles an error end event to the boundary on the sub-process" do
        execution = context.start(process_id: "ErrorBubble")

        _(execution.child_by_step_id("Sub").terminated?).must_equal true
        _(execution.child_by_step_id("OnError").ended?).must_equal true
        _(execution.child_by_step_id("Caught")).wont_be_nil  # boundary path taken
        _(execution.child_by_step_id("Normal")).must_be_nil  # normal path not taken
        _(execution.completed?).must_equal true
      end
    end

    describe "escalation" do
      let(:context) { BPMN.new(fixture_source("subprocess_boundary_escalation.bpmn")) }

      it "bubbles a thrown escalation to the boundary on the sub-process" do
        execution = context.start(process_id: "EscalationBubble")

        _(execution.child_by_step_id("Sub").terminated?).must_equal true
        _(execution.child_by_step_id("OnEscalation").ended?).must_equal true
        _(execution.child_by_step_id("Caught")).wont_be_nil
        _(execution.child_by_step_id("Normal")).must_be_nil
        _(execution.completed?).must_equal true
      end
    end
  end
end
