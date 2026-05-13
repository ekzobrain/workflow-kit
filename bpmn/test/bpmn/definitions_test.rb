# frozen_string_literal: true

require "test_helper"

module BPMN
  describe Definitions do
    describe :from_xml do
      describe :hello_world do
        let(:xml) { fixture_source("hello_world.bpmn") }
        let(:definitions) { Definitions.from_xml(xml) }

        it "should initialize the definitions" do
          _(definitions).wont_be_nil
          _(definitions.id).wont_be_nil
          _(definitions.execution_platform).must_equal("Camunda Cloud")
          _(definitions.execution_platform_version).wont_be_nil
          _(definitions.exporter).must_equal("Camunda Modeler")
          _(definitions.exporter_version).wont_be_nil
          _(definitions.target_namespace).must_equal("http://bpmn.io/schema/bpmn")
          _(definitions.messages.count).must_equal(0)
          _(definitions.signals.count).must_equal(0)
          _(definitions.errors.count).must_equal(0)
          _(definitions.item_definitions).must_equal([])
          _(definitions.processes.count).must_equal(1)
        end

        it "should have pretty inspect output" do
          _(definitions.inspect).wont_be_nil
        end
      end

      describe :item_definitions do
        let(:xml) { fixture_source("item_definitions.bpmn") }
        let(:definitions) { Definitions.from_xml(xml) }

        it "should parse item definitions from xml" do
          _(definitions.item_definitions.count).must_equal(2)
        end

        it "should initialize item definition attributes" do
          item_def = definitions.item_definitions.first
          _(item_def.id).must_equal("ItemDef_1")
          _(item_def.name).must_equal("String Item")
          _(item_def.structure_ref).must_equal("xsd:string")
        end

        it "should find item definition by id" do
          item_def = definitions.item_definition_by_id("ItemDef_2")
          _(item_def).wont_be_nil
          _(item_def.id).must_equal("ItemDef_2")
          _(item_def.name).must_equal("Integer Item")
          _(item_def.structure_ref).must_equal("xsd:integer")
        end

        it "should return nil for unknown item definition id" do
          _(definitions.item_definition_by_id("NonExistent")).must_be_nil
        end

        it "should include item definitions in inspect output" do
          _(definitions.inspect).must_include("item_definitions")
        end
      end
    end

  end
end
