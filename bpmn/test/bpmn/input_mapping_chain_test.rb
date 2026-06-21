# frozen_string_literal: true

require "test_helper"

module BPMN

  # Input mappings compile to a FEEL context, so a later mapping can reference an
  # earlier one in the same block (e.g. b = a + 1). They are applied in order,
  # each seeing the locals produced before it.
  describe "Chained input mappings" do
    let(:context) { BPMN.new(fixture_source("input_mapping_chain.bpmn")) }

    it "lets each input mapping reference earlier ones" do
      execution = context.start
      task = execution.child_by_step_id("Task")

      _(task.local_variables["a"]).must_equal 1
      _(task.local_variables["b"]).must_equal 2   # a + 1
      _(task.local_variables["c"]).must_equal 20  # b * 10
    end
  end
end
