# frozen_string_literal: true

require "test_helper"

module BPMN

  # A sub-process can declare a variable local via an input mapping. Writing to it
  # inside the sub-process updates the local copy (visible there), but it does not
  # leak into the parent on completion — unless an output mapping exposes it.
  describe "Sub-process local variable" do
    let(:context) { BPMN.new(fixture_source("subprocess_local_variable.bpmn")) }

    # The gem leaves script tasks waiting; run them (recursively) to drive inline.
    def drive(execution)
      100.times do
        node = next_automated(execution)
        break unless node
        node.run
      end
    end

    def next_automated(execution)
      execution.children.each do |child|
        return child if child.waiting? && child.step.is_a?(BPMN::ServiceTask)
        nested = next_automated(child)
        return nested if nested
      end
      nil
    end

    it "keeps a written local variable local, while an output mapping exports its updated value" do
      execution = context.start(variables: { x: 10 })
      drive(execution)

      _(execution.completed?).must_equal true
      _(execution.variables["x"]).must_equal 10      # local write did NOT leak to the parent
      _(execution.variables["x_out"]).must_equal 11  # output mapping exported the updated local (proves the write was visible inside)
    end
  end
end
