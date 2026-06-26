# frozen_string_literal: true

require "test_helper"

module BPMN

  describe "Signal events" do
    let(:context) { BPMN.new(fixture_source("signal.bpmn")) }

    it "parses a signalEventDefinition and resolves its signal" do
      catch_event = context.process_by_id("SignalCatch").element_by_id("Catch")
      _(catch_event.is_signal?).must_equal true
      _(catch_event.signal_event_definitions.first.signal_name).must_equal "ready"
    end

    it "waits at a signal catch event and leaves when signaled" do
      execution = context.start(process_id: "SignalCatch")
      catch_node = execution.child_by_step_id("Catch")
      _(catch_node.waiting?).must_equal true

      catch_node.signal
      _(catch_node.ended?).must_equal true
      _(execution.completed?).must_equal true
    end

    it "notifies :signal_thrown when a throw event is reached" do
      thrown = []
      BPMN.config.listener = ->(args) { thrown << args.last[:signal_name] if args.first == :signal_thrown }
      context.start(process_id: "SignalThrow")
      _(thrown).must_equal ["ready"]
    ensure
      BPMN.config.listener = nil
    end
  end
end
