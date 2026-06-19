# frozen_string_literal: true

require "test_helper"

module BPMN

  # Variables created in an outer scope must be visible in nested scopes
  # (sub-processes), with inner scopes shadowing outer ones — matching Zeebe.
  describe "Variable Scope" do
    let(:sources) { fixture_source("variable_scope.bpmn") }
    let(:context) { BPMN.new(sources) }

    before do
      @execution = context.start(variables: { total: 100, name: "outer" })
    end

    let(:execution) { @execution }
    let(:sub) { execution.child_by_step_id("Sub") }
    let(:inner) { sub.child_by_step_id("Inner") }

    it "exposes an outer-scope variable to a nested task" do
      _(inner.scope_variables["total"]).must_equal 100
    end

    it "shadows an outer variable with an inner-scope one" do
      # The sub-process io-maps name = "inner"; the inner task sees the inner value.
      _(inner.scope_variables["name"]).must_equal "inner"
      # The outer scope still holds the original.
      _(execution.scope_variables["name"]).must_equal "outer"
    end

    it "keeps an execution's own local variables in its scope" do
      _(sub.scope_variables["name"]).must_equal "inner"
      _(sub.scope_variables["total"]).must_equal 100
    end
  end
end
