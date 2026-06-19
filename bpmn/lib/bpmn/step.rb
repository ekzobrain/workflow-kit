# frozen_string_literal: true

module BPMN
  class Step < Element
    attr_accessor :incoming, :outgoing, :default, :default_ref, :multi_instance

    def initialize(attributes = {})
      super(attributes.except(:incoming, :outgoing, :default, :multi_instance_loop_characteristics))

      @incoming = Array.wrap(attributes[:incoming]) || []
      @outgoing = Array.wrap(attributes[:outgoing]) || []
      @default_ref = attributes[:default]
      @multi_instance = MultiInstance.from(attributes) if attributes.key?(:multi_instance_loop_characteristics)
    end

    def multi_instance?
      !multi_instance.nil?
    end

    def diverging?
      outgoing.length > 1
    end

    def converging?
      incoming.length > 1
    end

    def leave(execution)
      # A multi-instance instance completes inward — it notifies its body
      # instead of taking the activity's outgoing flows (the body takes them once
      # all instances are done).
      return execution.end(true) if execution.multi_instance_instance

      execution.end(false)
      execution.take_all(outgoing_flows(execution))
    end

    def outgoing_flows(execution)
      flows = []
      outgoing.each do |flow|
        result = flow.evaluate(execution) unless default&.id == flow.id
        flows.push flow if result
      end
      flows = [default] if flows.empty? && default
      return flows
    end

    def input_mappings
      extension_elements&.io_mapping&.inputs || []
    end

    def output_mappings
      extension_elements&.io_mapping&.outputs || []
    end
  end

  class Activity < Step
    attr_accessor :attachments

    def initialize(attributes = {})
      super(attributes.except(:attachments))

      @attachments = []
    end
  end
end
