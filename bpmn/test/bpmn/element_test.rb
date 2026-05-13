# frozen_string_literal: true

require "test_helper"

module BPMN
  describe Element do
    describe :definitions do
      let(:element) { Element.new(id: "id", name: "name") }

      it "should have pretty inspect output" do
        _(element.inspect).wont_be_nil
      end
    end
  end

  describe ItemDefinition do
    let(:item_definition) { ItemDefinition.new(id: "ItemDef_1", name: "String Item", structure_ref: "xsd:string") }

    it "should initialize with attributes" do
      _(item_definition.id).must_equal("ItemDef_1")
      _(item_definition.name).must_equal("String Item")
      _(item_definition.structure_ref).must_equal("xsd:string")
    end

    it "should initialize with no attributes" do
      item_def = ItemDefinition.new
      _(item_def.id).must_be_nil
      _(item_def.name).must_be_nil
      _(item_def.structure_ref).must_be_nil
    end
  end
end
