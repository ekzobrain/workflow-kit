# frozen_string_literal: true

require "test_helper"

module BPMN
  describe Expression do
    # A process: Start -> Script -> (gateway) -> End, with its expressions
    # replaceable to test the validation.
    def process_xml(condition: "=total &gt; 10", script: "=total * 2", input_source: "=total", loop_collection: "=items", assignee: "=owner", correlation_key: "=order_id", sub_process_script: "=1")
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:zeebe="http://camunda.org/schema/zeebe/1.0" id="Definitions" targetNamespace="http://bpmn.io/schema/bpmn">
          <bpmn:message id="Message" name="order">
            <bpmn:extensionElements><zeebe:subscription correlationKey="#{correlation_key}" /></bpmn:extensionElements>
          </bpmn:message>
          <bpmn:process id="Expressions" isExecutable="true">
            <bpmn:startEvent id="Start"><bpmn:outgoing>Flow_1</bpmn:outgoing></bpmn:startEvent>
            <bpmn:sequenceFlow id="Flow_1" sourceRef="Start" targetRef="Script" />
            <bpmn:scriptTask id="Script">
              <bpmn:extensionElements>
                <zeebe:script expression="#{script}" resultVariable="doubled" />
                <zeebe:ioMapping><zeebe:input source="#{input_source}" target="local_total" /></zeebe:ioMapping>
              </bpmn:extensionElements>
              <bpmn:incoming>Flow_1</bpmn:incoming>
              <bpmn:outgoing>Flow_2</bpmn:outgoing>
            </bpmn:scriptTask>
            <bpmn:sequenceFlow id="Flow_2" sourceRef="Script" targetRef="Gateway" />
            <bpmn:exclusiveGateway id="Gateway" default="Flow_Low"><bpmn:incoming>Flow_2</bpmn:incoming><bpmn:outgoing>Flow_High</bpmn:outgoing><bpmn:outgoing>Flow_Low</bpmn:outgoing></bpmn:exclusiveGateway>
            <bpmn:sequenceFlow id="Flow_High" sourceRef="Gateway" targetRef="Review">
              <bpmn:conditionExpression xsi:type="bpmn:tFormalExpression">#{condition}</bpmn:conditionExpression>
            </bpmn:sequenceFlow>
            <bpmn:sequenceFlow id="Flow_Low" sourceRef="Gateway" targetRef="End" />
            <bpmn:userTask id="Review">
              <bpmn:extensionElements><zeebe:assignmentDefinition assignee="#{assignee}" /></bpmn:extensionElements>
              <bpmn:multiInstanceLoopCharacteristics>
                <bpmn:extensionElements><zeebe:loopCharacteristics inputCollection="#{loop_collection}" inputElement="item" /></bpmn:extensionElements>
              </bpmn:multiInstanceLoopCharacteristics>
              <bpmn:incoming>Flow_High</bpmn:incoming>
              <bpmn:outgoing>Flow_3</bpmn:outgoing>
            </bpmn:userTask>
            <bpmn:sequenceFlow id="Flow_3" sourceRef="Review" targetRef="End" />
            <bpmn:subProcess id="Sub">
              <bpmn:scriptTask id="SubScript">
                <bpmn:extensionElements><zeebe:script expression="#{sub_process_script}" resultVariable="x" /></bpmn:extensionElements>
              </bpmn:scriptTask>
            </bpmn:subProcess>
            <bpmn:endEvent id="End"><bpmn:incoming>Flow_Low</bpmn:incoming><bpmn:incoming>Flow_3</bpmn:incoming></bpmn:endEvent>
          </bpmn:process>
        </bpmn:definitions>
      XML
    end

    def load_error(**options)
      assert_raises(BPMN::SyntaxError) { BPMN.new(process_xml(**options)) }
    end

    describe "when a definition is read" do
      it "should raise for an invalid expression, with the element and the attribute" do
        error = load_error(condition: "=total &gt;")
        _(error.message).must_equal 'Invalid expression in conditionExpression of element "Flow_High": "=total >"'
        _(error.element_id).must_equal "Flow_High"
        _(error.attribute).must_equal "conditionExpression"
        _(error.expression).must_equal "=total >"
        _(error).must_be_kind_of FEEL::SyntaxError
        _(error).must_be_kind_of FEEL::Error
      end

      it "should check every kind of expression" do
        _(load_error(script: "=total *").message).must_match(/zeebe:script expression of element "Script"/)
        _(load_error(input_source: "=(total").message).must_match(/zeebe:input source \(target "local_total"\) of element "Script"/)
        _(load_error(loop_collection: "=items[").message).must_match(/zeebe:loopCharacteristics inputCollection of element "Review"/)
        _(load_error(assignee: "=owner +").message).must_match(/zeebe:assignmentDefinition assignee of element "Review"/)
        _(load_error(correlation_key: "=order_id +").message).must_match(/zeebe:subscription correlationKey of element "Message"/)
        _(load_error(sub_process_script: "=1 +").message).must_match(/zeebe:script expression of element "SubScript"/)
        _(load_error(condition: "=").message).must_match(/conditionExpression/)
      end

      it "should accept static values" do
        context = BPMN.new(process_xml(assignee: "john", correlation_key: "order-1"))
        review = context.element_by_id("Review")
        _(review.expression("zeebe:assignmentDefinition assignee", "john").expression?).must_equal false
        _(review.expression("zeebe:assignmentDefinition assignee", "john").evaluate).must_equal "john"
      end

      it "should compile the expressions once" do
        flow = BPMN.new(process_xml).element_by_id("Flow_High")
        _(flow.condition_expression).must_be_same_as flow.condition_expression
        _(flow.condition_expression.expression?).must_equal true
        _(flow.condition_expression.evaluate(total: 11)).must_equal true
      end
    end

    describe "when a process is executed" do
      it "should evaluate the compiled expressions" do
        execution = BPMN.new(process_xml).start(variables: { total: 20, items: [1, 2], owner: "ann" })
        execution.child_by_step_id("Script").run
        _(execution.variables["doubled"]).must_equal 40
        review = execution.child_by_step_id("Review")
        _(review.children.count(&:multi_instance_instance)).must_equal 2

        execution = BPMN.new(process_xml).start(variables: { total: 5, items: [] })
        execution.child_by_step_id("Script").run
        _(execution.child_by_step_id("Review")).must_be_nil
        _(execution.ended?).must_equal true
      end
    end

    describe "mappings" do
      def mapping_xml(source)
        process_xml(input_source: source.encode(xml: :attr)[1...-1])
      end

      def local_total(source, variables = { total: 1 })
        execution = BPMN.new(mapping_xml(source)).start(variables: variables.merge(items: []))
        execution.child_by_step_id("Script").local_variables["local_total"]
      end

      it "should support expressions ending with a comment" do
        _(local_total("=total + 1 // one more")).must_equal 2
      end

      it "should keep static values as they are" do
        _(local_total('a "quoted" #{value}\\n')).must_equal 'a "quoted" #{value}\\n'
      end
    end

    describe "Execution#evaluate_expression" do
      it "should still accept texts" do
        execution = BPMN.new(process_xml).start(variables: { total: 5, items: [] })
        _(execution.evaluate_expression("=total + 1")).must_equal 6
        _(execution.evaluate_expression("static")).must_equal "static"
        _(execution.evaluate_expression(Expression.new("=total * 3"))).must_equal 15
      end
    end
  end
end
