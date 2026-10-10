# Expressions

Expressions are evaluated at execution time to make decisions. They are frequently used to conditionally take a sequence flow but can also be used to determine a value dynamically (for example which process to call from a CallActivity). This engine supports FEEL expressions or JSONLogic.

[Try Feel](https://nikku.github.io/feel-playground) | 
[Try JSONLogic](https://jsonlogic.com/play.html)

Required Expressions:
- Sequence flow on an exclusive gateway: condition
- Message catch event/receive task (not yet implemented) 
- Multi-instance activity: input collection, output element (not yet implemented)
- Input/output variable mappings: source (not yet implemented)

Optional Expressions (conditions can be used in place of a static value):
- Call activity: process id
- Timer catch event: timer definition (not yet implemented) 
- Message catch event/receive task: message name (not yet implemented) 
- Service task: job type, job retries (not yet implemented) 

An attribute value starting with `=` is a FEEL expression; any other value is a static value. All the expressions of a definition are parsed and compiled once, when it is read (`BPMN.new`, `BPMN.restore`, `BPMN.processes_from_xml`), and only evaluated during the execution. An invalid expression raises `BPMN::SyntaxError` (a `FEEL::SyntaxError`) at that point, with the element and the attribute:

```ruby
BPMN.new(xml)
# => BPMN::SyntaxError: Invalid expression in conditionExpression of element "Flow_High": "=total >"
#    error.element_id # => "Flow_High", error.attribute # => "conditionExpression"
```

This covers sequence flow conditions, scripts, input/output mapping sources, multi-instance input collections and output elements, called process and decision ids, and the Zeebe attributes that accept expressions (assignee, candidate groups and users, form external reference, message correlation key, job type and retries, due and follow-up dates).

Note: sequence flows allow a script instead of an expression. This should only be used when a util function is needed.

## Sequence Flow

A sequence flow represents the transition in a process from one step to another. Sequence flows can specify conditions that are checked to determine if the path should be taken.