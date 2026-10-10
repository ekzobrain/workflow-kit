# frozen_string_literal: true

require "test_helper"

module DMN
  describe Definitions do
    describe :from_xml do
      let(:xml) { fixture_source("test.dmn") }
      let(:definitions) { Definitions.from_xml(xml) }

      it "should parse definitions" do
        _(definitions).wont_be_nil
        _(definitions.execution_platform).must_equal("Camunda Cloud")
        _(definitions.execution_platform_version).wont_be_nil
        _(definitions.exporter).must_equal("Camunda Modeler")
        _(definitions.exporter_version).wont_be_nil
        _(definitions.id).must_equal("test")
        _(definitions.name).must_equal("Test")
        _(definitions.namespace).must_equal("http://camunda.org/schema/1.0/dmn")
        _(definitions.decisions.size).must_equal(2)
      end
    end

    describe :compile! do
      def table_xml(input_expression: "category", input_entry: '"A"', output_entry: '"yes"')
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/" id="defs" name="Defs" namespace="http://camunda.org/schema/1.0/dmn">
            <decision id="check" name="Check">
              <decisionTable id="table" hitPolicy="FIRST">
                <input id="input_1" label="Category">
                  <inputExpression id="input_expression_1" typeRef="string"><text>#{input_expression}</text></inputExpression>
                </input>
                <output id="output_1" label="Result" name="result" typeRef="string" />
                <rule id="rule_1">
                  <inputEntry id="entry_1"><text>#{input_entry}</text></inputEntry>
                  <outputEntry id="entry_2"><text>#{output_entry}</text></outputEntry>
                </rule>
              </decisionTable>
            </decision>
          </definitions>
        XML
      end

      def literal_xml(text)
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <definitions xmlns="https://www.omg.org/spec/DMN/20191111/MODEL/" id="defs" name="Defs" namespace="http://camunda.org/schema/1.0/dmn">
            <decision id="total" name="Total">
              <variable id="var" name="total" typeRef="number" />
              <literalExpression id="literal"><text>#{text}</text></literalExpression>
            </decision>
          </definitions>
        XML
      end

      def load_error(xml)
        assert_raises(DMN::SyntaxError) { Definitions.from_xml(xml) }
      end

      it "should raise when the definitions are loaded if an expression is not valid" do
        _(load_error(table_xml(input_expression: "category +")).message).must_equal %(Invalid expression in decision "check", input 'Category': "category +")
        _(load_error(table_xml(input_entry: "&lt; ")).message).must_equal %(Invalid expression in decision "check", rule "rule_1", input entry 'Category': "<")
        _(load_error(table_xml(output_entry: '"a" +')).message).must_equal "Invalid expression in decision \"check\", rule \"rule_1\", output entry 'result': #{'"a" +'.inspect}"
        _(load_error(literal_xml("a +")).message).must_equal %(Invalid expression in decision "total": "a +")
        _(load_error(literal_xml("")).message).must_match(/decision "total"/)
        _(load_error(literal_xml("a +"))).must_be_kind_of FEEL::SyntaxError
      end

      it "should accept empty input and output entries" do
        definitions = Definitions.from_xml(table_xml(input_entry: "", output_entry: ""))
        _(definitions.evaluate("check", variables: { category: "B" })).must_equal({})
        _(Definitions.from_xml(table_xml(input_entry: "-")).evaluate("check", variables: { category: "B" })).must_equal({ "result" => "yes" })
      end

      it "should share the parsed expressions between definitions" do
        first = Definitions.from_xml(table_xml)
        second = Definitions.from_xml(table_xml)
        _(second.decisions.first.decision_table.rules.first.input_entries.first.tree).must_be_same_as first.decisions.first.decision_table.rules.first.input_entries.first.tree
        _(second.decisions.first.decision_table.inputs.first.input_expression.tree).must_be_same_as first.decisions.first.decision_table.inputs.first.input_expression.tree
      end
    end

    describe :evaluate do
      it "should evaluate decisions with dependencies" do
        definitions = Definitions.from_xml(fixture_source("test.dmn"))
        variables = {
          input: {
            category: "E",
            reference_date: Date.new(2018, 01, 04),
            test_date: Date.new(2018, 01, 03),
          },
        }

        result = definitions.evaluate("primary_decision", variables: variables)
        _(result[:output][:score]).must_equal(50)

        variables[:input][:test_date] = Date.new(2018, 04, 04)
        result = definitions.evaluate("primary_decision", variables: variables)
        _(result[:output][:score]).must_equal(100)

        variables[:input][:test_date] = Date.new(2018, 04, 05)
        result = definitions.evaluate("primary_decision", variables: variables)
        _(result[:output][:score]).must_equal(0)
      end
    end
  end
end
