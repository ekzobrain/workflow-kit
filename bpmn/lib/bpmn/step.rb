# frozen_string_literal: true

module BPMN
  class Step < Element
    attr_accessor :incoming, :outgoing, :default, :default_ref, :multi_instance, :attachments

    def initialize(attributes = {})
      super(attributes.except(:incoming, :outgoing, :default, :multi_instance_loop_characteristics))

      @incoming = Array.wrap(attributes[:incoming]) || []
      @outgoing = Array.wrap(attributes[:outgoing]) || []
      @default_ref = attributes[:default]
      @multi_instance = MultiInstance.from(attributes) if attributes.key?(:multi_instance_loop_characteristics)
      # Boundary events attached to this step (wired at parse). On Step (not just
      # Activity) so sub-processes can host boundary events too.
      @attachments = []
    end

    def multi_instance?
      !multi_instance.nil?
    end

    def diverging?
      outgoing.length > 1
    end

    def converging?
      incoming.length > 1
    end

    def leave(execution)
      # A multi-instance instance completes inward — it notifies its body
      # instead of taking the activity's outgoing flows (the body takes them once
      # all instances are done).
      return execution.end(true) if execution.multi_instance_instance

      execution.end(false)
      execution.take_all(outgoing_flows(execution))
    end

    def outgoing_flows(execution)
      flows = []
      outgoing.each do |flow|
        result = flow.evaluate(execution) unless default&.id == flow.id
        flows.push flow if result
      end
      flows = [default] if flows.empty? && default
      return flows
    end

    def input_mappings
      extension_elements&.io_mapping&.inputs || []
    end

    def output_mappings
      extension_elements&.io_mapping&.outputs || []
    end

    # Whether the raw (un-mapped) local variables propagate to the parent scope on
    # completion. By default they do only when there are no output mappings —
    # output mappings turn the activity into a local scope (Zeebe semantics).
    def propagate_unmapped_variables?
      output_mappings.blank?
    end

    # The ioMapping entries compiled into a single FEEL context expression (dotted
    # targets nested, later entries can reference earlier ones), or nil when there
    # are none. These depend only on the static schema, so they're built once per
    # step rather than rebuilt on every execution. See #compile_mappings.
    def input_mappings_expression
      return @input_mappings_expression if defined?(@input_mappings_expression)
      @input_mappings_expression = compile_mappings(input_mappings)
    end

    def output_mappings_expression
      return @output_mappings_expression if defined?(@output_mappings_expression)
      @output_mappings_expression = compile_mappings(output_mappings)
    end

    private

    # Builds one nested FEEL context literal from the mappings, e.g.
    #   [a -> =1, b -> =a+1, auth.type -> "basic"]
    #   => ={"a": (1), "b": (a + 1), "auth": {"type": "basic"}}
    # Quoted string keys are required by FEEL and also make dotted/special-char
    # target segments safe.
    def compile_mappings(mappings)
      return nil if mappings.blank?

      tree = {}
      mappings.each do |parameter|
        segments = parameter.target.to_s.split(".")
        leaf = segments[0..-2].inject(tree) { |node, segment| node[segment] ||= {} }
        leaf[segments[-1]] = parameter.source
      end
      "=" + render_feel_context(tree)
    end

    def render_feel_context(tree)
      entries = tree.map do |key, value|
        rendered = value.is_a?(Hash) ? render_feel_context(value) : feel_mapping_value(value)
        "#{key.inspect}: #{rendered}"
      end
      "{#{entries.join(", ")}}"
    end

    # A "=..." source is a FEEL expression (embedded, parenthesised for safety);
    # anything else is a literal value (emitted as a quoted FEEL string).
    def feel_mapping_value(source)
      source = source.to_s
      source.start_with?("=") ? "(#{source.delete_prefix("=")})" : source.inspect
    end
  end

  class Activity < Step
  end
end
