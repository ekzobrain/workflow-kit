# frozen_string_literal: true

require "test_helper"
require "bigdecimal"

# Ported from feel-scala: SpecExampleTest
module FEEL
  describe "spec examples" do
    CONTEXT_EXPRESSION = <<~FEEL
      {
        applicant: {
          age: 51,
          maritalStatus: "M",
          existingCustomer: false,
          monthly: {
            income: 10000,
            repayments: 2500,
            expenses: 3000
          }
        },
        requested_product: {
          product_type: "STANDARD LOAN",
          rate: 0.25,
          term: 36,
          amount: 100000
        },
        monthly_income: applicant.monthly.income,
        monthly_outgoings: [applicant.monthly.repayments, applicant.monthly.expenses],
        credit_history: [
          {
            record_date: date("2008-03-12"),
            event: "home mortgage",
            weight: 100
          },
          {
            record_date: date("2011-04-01"),
            event: "foreclosure warning",
            weight: 150
          }
        ],
        PMT: function(rate, term, amount) (amount *rate/12) / (1 - (1 + rate/12)**-term)
      }
    FEEL

    def evaluate(expression, variables = {})
      FEEL.evaluate(expression, variables: variables)
    end

    def eval_with_context(expression)
      evaluate(expression, evaluate(CONTEXT_EXPRESSION))
    end

    describe "The FEEL engine" do
      it "should calculate" do
        _(eval_with_context(" monthly_income * 12  ")).must_equal 120_000
      end

      it "should evaluate an if,in" do
        _(eval_with_context(' if applicant.maritalStatus in ("M","S") then "valid" else "not valid" ')).must_equal "valid"
      end

      it "should sum entries of a list" do
        _(eval_with_context(" sum(monthly_outgoings) ")).must_equal 5500
      end

      it "should invoke an user-defined function" do
        rate = BigDecimal("0.25")
        amount = BigDecimal("100000")
        expected = (amount * rate / 12) / (1 - (1 + rate / 12)**-36)

        result = eval_with_context(<<~FEEL)
          PMT(
            requested_product . rate,
            requested_product . term,
            requested_product . amount
          )
        FEEL
        # ~ 3975.982590125562
        _(result).must_be_close_to expected.to_f, 1e-9
      end

      it "should sum a filtered list of context" do
        _(eval_with_context(' sum( credit_history[record_date > date("2011-01-01")].weight) ')).must_equal 150
      end

      it "should determine if list satisfies" do
        _(eval_with_context(' some ch in credit_history satisfies ch.event = "bankruptcy" ')).must_equal false
      end

      it "should execute nested path and filter expressions" do
        ctx = {
          "EmployeeTable" => [
            { "id" => 7792, "deptNum" => 10, "name" => "Clark" },
            { "id" => 7934, "deptNum" => 10, "name" => "Miller" },
            { "id" => 7976, "deptNum" => 20, "name" => "Adams" },
            { "id" => 7902, "deptNum" => 20, "name" => "Ford" },
            { "id" => 7900, "deptNum" => 30, "name" => "James" },
          ],
          "DeptTable" => [
            { "number" => 10, "name" => "Sales", "manager" => "Smith" },
            { "number" => 20, "name" => "Finance", "manager" => "Jones" },
            { "number" => 30, "name" => "Engineering", "manager" => "King" },
          ],
          "LastName" => "Clark",
        }

        _(evaluate("DeptTable[number = EmployeeTable[name=LastName].deptNum[1]].manager[1]", ctx)).must_equal "Smith"
      end
    end
  end
end
