# frozen_string_literal: true

require "test_helper"

module BPMN

  # Sub-processes nest: a sub-process inside a sub-process is a scope of its own,
  # can host boundary events, and is reachable by id from the context.
  describe "Nested sub-process" do
    let(:context) { BPMN.new(fixture_source("nested_subprocess.bpmn")) }
    let(:process) { context.process_by_id("Nested") }
    let(:outer) { process.element_by_id("Outer") }

    it "parses a sub-process nested in a sub-process" do
      _(outer.sub_processes.map(&:id)).must_equal ["Inner"]
      _(outer.element_by_id("Inner").element_by_id("InnerStart")).wont_be_nil
    end

    it "resolves a nested element by id from the process and the context" do
      _(process.element_by_id("InnerEnd")).wont_be_nil
      _(context.element_by_id("InnerEnd")).wont_be_nil
      _(context.process_by_id("Inner")).must_equal outer.element_by_id("Inner")
    end

    it "attaches a boundary event to the nested sub-process it names" do
      inner = outer.element_by_id("Inner")

      _(inner.attachments.map(&:id)).must_equal ["OnInnerError"]
      _(outer.element_by_id("OnInnerError").attached_to).must_equal inner
    end

    it "skips a property left empty and keeps the rest" do
      _(outer.element_by_id("Inner").extension_elements.properties).must_equal("note" => "kept")
    end

    it "runs through both levels" do
      execution = context.start(process_id: "Nested")

      _(execution.child_by_step_id("Outer").completed?).must_equal true
      _(execution.child_by_step_id("Outer").child_by_step_id("Inner").completed?).must_equal true
      _(execution.completed?).must_equal true
    end

    it "catches an error from the nested sub-process on its own boundary" do
      execution = context.start(process_id: "NestedError")
      outer_execution = execution.child_by_step_id("EOuter")

      _(outer_execution.child_by_step_id("EInner").terminated?).must_equal true
      _(outer_execution.child_by_step_id("EOnInnerError").ended?).must_equal true
      _(outer_execution.child_by_step_id("ECaught")).wont_be_nil
      _(outer_execution.child_by_step_id("ENormal")).must_be_nil
      _(execution.completed?).must_equal true
    end
  end
end
