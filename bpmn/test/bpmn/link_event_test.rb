# frozen_string_literal: true

require "test_helper"

module BPMN

  # Link events are an intra-process "go to": a throw-link jumps to the catch-link
  # with the same name in the same scope. Here two throw-links converge on one
  # catch-link (many-to-one).
  describe "Link Event" do
    let(:sources) { fixture_source("link_event.bpmn") }
    let(:context) { BPMN.new(sources) }
    let(:process) { context.process_by_id("LinkEvent") }

    describe :definition do
      it "parses throw-links and the catch-link by name" do
        _(process.element_by_id("ThrowA").is_link?).must_equal true
        _(process.element_by_id("ThrowA").is_throwing?).must_equal true
        _(process.element_by_id("ThrowA").link_name).must_equal "handler"
        _(process.element_by_id("ThrowB").link_name).must_equal "handler"

        _(process.element_by_id("Handler").is_link?).must_equal true
        _(process.element_by_id("Handler").is_catching?).must_equal true
        _(process.element_by_id("Handler").link_name).must_equal "handler"
      end
    end

    describe :execution do
      it "jumps from the first throw to the shared catch and continues" do
        execution = context.start(variables: { choice: "a" })

        _(execution.child_by_step_id("ThrowA").ended?).must_equal true
        _(execution.child_by_step_id("Handler")).wont_be_nil
        _(execution.child_by_step_id("Handler").ended?).must_equal true
        _(execution.completed?).must_equal true
      end

      it "jumps from the second throw to the same catch" do
        execution = context.start(variables: { choice: "b" })

        _(execution.child_by_step_id("ThrowB").ended?).must_equal true
        _(execution.child_by_step_id("Handler")).wont_be_nil
        _(execution.completed?).must_equal true
      end
    end
  end
end
