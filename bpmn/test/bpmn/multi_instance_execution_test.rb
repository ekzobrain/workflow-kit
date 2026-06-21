# frozen_string_literal: true

require "test_helper"

module BPMN

  describe "Multi Instance Execution" do
    let(:sources) { fixture_source("multi_instance_execution.bpmn") }
    let(:context) { BPMN.new(sources) }

    describe "parallel" do
      before { @execution = context.start(process_id: "ParallelReview", variables: { items: [10, 20, 30] }) }

      let(:execution) { @execution }
      let(:body) { execution.child_by_step_id("PReview") }
      let(:instances) { body.multi_instance_instances }

      it "spawns one waiting instance per item with the input element bound" do
        _(instances.length).must_equal 3
        _(instances.map(&:status).uniq).must_equal ["waiting"]
        _(instances.map { |instance| instance.local_variables["item"] }).must_equal [10, 20, 30]
      end

      it "completes the body only once every instance has finished" do
        instances[0].signal({ score: 1 })
        _(body.ended?).must_equal false
        instances[1].signal({ score: 2 })
        _(body.ended?).must_equal false
        instances[2].signal({ score: 3 })
        _(body.ended?).must_equal true
        _(execution.ended?).must_equal true
      end

      it "assembles outputCollection in input order regardless of completion order" do
        instances[2].signal({ score: 30 })
        instances[0].signal({ score: 10 })
        instances[1].signal({ score: 20 })
        _(execution.variables["results"]).must_equal [10, 20, 30]
      end
    end

    describe "sequential" do
      before { @execution = context.start(process_id: "SequentialReview", variables: { items: [10, 20, 30] }) }

      let(:execution) { @execution }
      let(:body) { execution.child_by_step_id("SReview") }

      it "activates one instance at a time" do
        _(body.multi_instance_instances.length).must_equal 1
        _(body.multi_instance_instances.last.local_variables["item"]).must_equal 10

        body.multi_instance_instances.last.signal({ score: 1 })
        _(body.multi_instance_instances.length).must_equal 2
        _(body.multi_instance_instances.last.local_variables["item"]).must_equal 20

        body.multi_instance_instances.last.signal({ score: 2 })
        _(body.multi_instance_instances.length).must_equal 3
        _(body.multi_instance_instances.last.local_variables["item"]).must_equal 30
      end

      it "assembles outputCollection in order and completes" do
        3.times { |i| body.multi_instance_instances.last.signal({ score: (i + 1) * 100 }) }
        _(execution.variables["results"]).must_equal [100, 200, 300]
        _(execution.ended?).must_equal true
      end
    end

    describe "empty collection" do
      before { @execution = context.start(process_id: "ParallelReview", variables: { items: [] }) }

      let(:execution) { @execution }

      it "skips the activity, assembles an empty output collection and completes" do
        _(execution.child_by_step_id("PReview").multi_instance_instances).must_be_empty
        _(execution.variables["results"]).must_equal []
        _(execution.ended?).must_equal true
      end
    end
  end
end
