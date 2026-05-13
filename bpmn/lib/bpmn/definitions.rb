# frozen_string_literal: true

module BPMN
  class Definitions
    include ActiveModel::Model

    MODEL_ATTRIBUTES = %i[
      id name target_namespace exporter exporter_version execution_platform execution_platform_version
    ].freeze

    attr_accessor :id, :name, :target_namespace, :exporter, :exporter_version, :execution_platform, :execution_platform_version
    attr_reader :messages, :signals, :errors, :escalations, :item_definitions, :processes

    def self.from_xml(xml)
      XmlHasher.configure do |config|
        config.snakecase = true
        config.ignore_namespaces = true
        config.string_keys = false
      end
      hash = XmlHasher.parse(xml)
      Definitions.new(hash[:definitions].except(:bpmn_diagram)).tap do |definitions|
        definitions.processes.each do |process|
          process.wire_references(definitions)
        end
      end
    end

    def initialize(attributes={})
      super(attributes.slice(*MODEL_ATTRIBUTES))

      @messages = Array.wrap(attributes[:message]).map { |atts| Message.new(atts) }
      @signals = Array.wrap(attributes[:signal]).map { |atts| Signal.new(atts) }
      @errors = Array.wrap(attributes[:error]).map { |atts| Error.new(atts) }
      @escalations = Array.wrap(attributes[:escalation]).map { |atts| Escalation.new(atts) }
      @item_definitions = Array.wrap(attributes[:item_definition]).map { |atts| ItemDefinition.new(atts) }
      @processes = Array.wrap(attributes[:process]).map { |atts| Process.new(atts) }
    end

    def message_by_id(id)
      messages.find { |message| message.id == id }
    end

    def signal_by_id(id)
      signals.find { |signal| signal.id == id }
    end

    def error_by_id(id)
      errors.find { |error| error.id == id }
    end

    def escalation_by_id(id)
      escalations.find { |escalation| escalation.id == id }
    end

    def process_by_id(id)
      processes.find { |process| process.id == id }
    end

    def item_definition_by_id(id)
      item_definitions.find { |item| item.id == id }
    end

    def inspect
      "#<BPMN::Definitions @id=#{id.inspect} @name=#{name.inspect} @messages=#{messages.inspect} @signals=#{signals.inspect} @errors=#{errors.inspect} @escalations=#{escalations.inspect} @item_definitions=#{item_definitions.inspect} @processes=#{processes.inspect}>"
    end
  end
end
