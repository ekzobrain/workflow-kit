# frozen_string_literal: true

module BPMN
  # Raised while reading a BPMN file that parses as XML but does not describe a
  # usable model — e.g. a reference pointing at an element that is not there.
  class InvalidDefinitionError < StandardError; end

  class Element
    include ActiveModel::Model

    attr_accessor :id, :name, :extension_elements

    def initialize(attributes = {})
      super(attributes.slice(:id, :name))

      @extension_elements = ExtensionElements.new(attributes[:extension_elements]) if attributes[:extension_elements].present?
    end

    # The Zeebe extension attributes that may be FEEL expressions ("=..."),
    # by extension element, with their name in the XML.
    EXTENSION_EXPRESSIONS = {
      assignment_definition: { assignee: "zeebe:assignmentDefinition assignee", candidate_groups: "zeebe:assignmentDefinition candidateGroups", candidate_users: "zeebe:assignmentDefinition candidateUsers" },
      called_decision: { decision_id: "zeebe:calledDecision decisionId" },
      called_element: { process_id: "zeebe:calledElement processId" },
      form_definition: { external_reference: "zeebe:formDefinition externalReference" },
      subscription: { correlation_key: "zeebe:subscription correlationKey" },
      task_definition: { type: "zeebe:taskDefinition type", retries: "zeebe:taskDefinition retries" },
      task_schedule: { due_date: "zeebe:taskSchedule dueDate", follow_up_date: "zeebe:taskSchedule followUpDate" },
    }.freeze

    # The compiled value of an attribute (see BPMN::Expression), compiled once:
    # all the expressions of a definition are compiled when it is read (see
    # #compile_expressions).
    def expression(attribute, text)
      return nil if text.nil?

      @expressions ||= {}
      cached = @expressions[attribute]
      return cached if cached && cached.text == text

      @expressions[attribute] = Expression.compile(text, element: self, attribute: attribute)
    end

    # Compiles the expressions of the element, raising BPMN::SyntaxError for
    # an invalid one. Subclasses add their own expressions.
    def compile_expressions
      EXTENSION_EXPRESSIONS.each do |extension, attributes|
        extension_element = extension_elements&.public_send(extension)
        next unless extension_element

        attributes.each { |attribute, label| expression(label, extension_element.public_send(attribute)) }
      end
    end

    def inspect
      "#<#{self.class.name.gsub(/BPMN::/, "")} @id=#{id.inspect} @name=#{name.inspect}>"
    end
  end

  class Message < Element
  end

  class Signal < Element
  end

  class Error < Element
  end

  class Escalation < Element
  end

  class ItemDefinition < Element
    attr_accessor :structure_ref

    def initialize(attributes = {})
      super(attributes)
      @structure_ref = attributes[:structure_ref]
    end
  end

  class Collaboration < Element
  end

  class LaneSet < Element
  end

  class Participant < Element
    attr_accessor :process_ref, :process

    def initialize(attributes = {})
      super(attributes.except(:process_ref))
    end
  end
end
