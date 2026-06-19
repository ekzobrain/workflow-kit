# frozen_string_literal: true

require "test_helper"

module BPMN

  describe "Multi Instance" do
    let(:sources) { fixture_source("multi_instance.bpmn") }
    let(:context) { BPMN.new(sources) }
    let(:process) { context.process_by_id("MultiInstance") }
    let(:notify) { process.element_by_id("Notify") }
    let(:each) { process.element_by_id("Each") }
    let(:start_event) { process.element_by_id("Start") }

    it "parses a parallel multi-instance task" do
      _(notify.multi_instance?).must_equal true
      _(notify.multi_instance.sequential?).must_equal false
      _(notify.multi_instance.input_collection).must_equal "=recipients"
      _(notify.multi_instance.input_element).must_equal "recipient"
      _(notify.multi_instance.output_collection).must_be_nil
    end

    it "parses a sequential multi-instance sub-process with output" do
      _(each.multi_instance?).must_equal true
      _(each.multi_instance.sequential?).must_equal true
      _(each.multi_instance.input_collection).must_equal "=orders"
      _(each.multi_instance.input_element).must_equal "order"
      _(each.multi_instance.output_collection).must_equal "results"
      _(each.multi_instance.output_element).must_equal "=order.total"
    end

    it "leaves non-multi-instance steps unaffected" do
      _(start_event.multi_instance?).must_equal false
      _(start_event.multi_instance).must_be_nil
    end
  end
end
