# frozen_string_literal: true

require "test_helper"

module BPMN

  describe "IO Mapping" do
    let(:sources) { fixture_source("io_mapping.bpmn") }
    let(:context) { BPMN.new(sources) }

    describe :definition do
      let(:process) { context.process_by_id("IOMapping") }
      let(:start_event) { process.element_by_id("Start") }
      let(:collect_money) { process.element_by_id("CollectMoney") }
      let(:end_event) { process.element_by_id("End") }

      it "should parse the task with io mappings" do
        _(collect_money).wont_be_nil
        _(collect_money.input_mappings.present?).must_equal true
        _(collect_money.input_mappings.length).must_equal 4
        _(collect_money.output_mappings.present?).must_equal true
        _(collect_money.output_mappings.length).must_equal 1
      end
    end

    describe :execution do
      before { @execution = context.start(variables: { order_id: "order-123", total_price: 25.0, customer: { name: "John", iban: "DE456" } }); }

      let(:execution) { @execution }
      let(:start_event) { execution.child_by_step_id("Start") }
      let(:collect_money) { execution.child_by_step_id("CollectMoney") }
      let(:end_event) { execution.child_by_step_id("End") }

      describe :input_mapping do
        it "creates input-mapped variables in the local scope, not the result variables" do
          # Input mappings create LOCAL variables (visible to the activity and its
          # children) — they are not result variables and do not propagate up.
          _(collect_money.local_variables["sender"]).must_equal "John"
          _(collect_money.local_variables["iban"]).must_equal "DE456"
          _(collect_money.local_variables["price"]).must_equal 25
          _(collect_money.local_variables["reference"]).must_equal "order-123"

          _(collect_money.variables["sender"]).must_be_nil
          _(collect_money.scope_variables["sender"]).must_equal "John"
        end

        describe :output_mapping do
          before { collect_money.signal({ payment_status: "OK" }) }

          it "maps the payload through the output mapping (status), discarding the raw payload" do
            # Output mappings define a local scope: only the mapped variable
            # (status) propagates; the raw completion payload (payment_status) does
            # not leak into the process variables.
            _(execution.variables["status"]).must_equal "OK"
            _(execution.variables["payment_status"]).must_be_nil
          end
        end
      end
    end
  end
end
