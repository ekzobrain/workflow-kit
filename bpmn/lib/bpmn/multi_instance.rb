# frozen_string_literal: true

module BPMN
  # Multi-instance loop configuration for an activity or sub-process: the step is
  # run once per item of inputCollection, with inputElement bound in each
  # instance's scope, optionally collecting outputElement into outputCollection.
  # Parallel by default; sequential when isSequential is set.
  class MultiInstance
    attr_reader :loop_characteristics

    # Builds from a step's parsed attributes. The Zeebe/Camunda shape nests the
    # config inside the marker, not the task's own extension elements:
    #   <bpmn:multiInstanceLoopCharacteristics isSequential="true">
    #     <bpmn:extensionElements>
    #       <zeebe:loopCharacteristics inputCollection="…" inputElement="…"
    #                                  outputCollection="…" outputElement="…" />
    #     </bpmn:extensionElements>
    #   </bpmn:multiInstanceLoopCharacteristics>
    def self.from(attributes)
      marker = attributes[:multi_instance_loop_characteristics]
      marker = {} unless marker.is_a?(Hash)
      sequential = marker[:is_sequential].to_s == "true"
      extension_elements = ExtensionElements.new(marker[:extension_elements]) if marker[:extension_elements].present?
      new(sequential: sequential, loop_characteristics: extension_elements&.loop_characteristics)
    end

    def initialize(sequential:, loop_characteristics:)
      @sequential = sequential
      @loop_characteristics = loop_characteristics
    end

    def sequential?
      @sequential
    end

    def input_collection
      loop_characteristics&.input_collection
    end

    def input_element
      loop_characteristics&.input_element
    end

    def output_collection
      loop_characteristics&.output_collection
    end

    def output_element
      loop_characteristics&.output_element
    end
  end
end
