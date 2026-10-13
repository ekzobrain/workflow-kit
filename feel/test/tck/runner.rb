# frozen_string_literal: true

require "feel"
require "nokogiri"
require "bigdecimal"

module FEEL
  #
  # Runs the test cases of the DMN TCK (https://github.com/dmn-tck/tck) with
  # FEEL: the boxed expressions of the models (literal expressions, contexts,
  # invocations, lists, relations, function definitions, conditionals,
  # filters, iterations, decision tables) are translated into FEEL text and
  # evaluated by FEEL. BKMs become FEEL functions. See test/tck/README.md.
  #
  module TCK
    # A feature of DMN that the runner doesn't translate (e.g. decision
    # services, imports).
    class Unsupported < StandardError; end

    Result = Struct.new(:folder, :file, :id, :status, :details) do
      def key = "#{folder}/#{file}##{id}"
    end

    # A DMN model (definitions).
    class Model
      attr_reader :decisions, :bkms, :inputs, :services, :item_definitions

      def initialize(path)
        doc = Nokogiri::XML(File.read(path))
        doc.remove_namespaces!
        root = doc.root
        raise Unsupported, "import" if root.xpath("import").any?

        @inputs = root.xpath("inputData").to_h { |el| [el["id"] || el["name"], el["name"]] }
        @decisions = root.xpath("decision").to_h { |el| [el["id"] || el["name"], el] }
        @bkms = root.xpath("businessKnowledgeModel").to_h { |el| [el["id"] || el["name"], el] }
        @services = root.xpath("decisionService").to_h { |el| [el["id"] || el["name"], el] }
        @item_definitions = root.xpath("itemDefinition").to_h { |el| [el["name"], el] }
        # Names with spaces or other characters must be escaped with backticks
        # in FEEL: a DMN engine escapes the names of the model before parsing
        # the expressions (as the DMN engine of Camunda does).
        @names = doc.xpath("//@name").map(&:value).uniq
          .select { |name| name.match?(/\A[[:alpha:]_]/) && !name.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) }
          .sort_by { |name| -name.length }
      end

      # Escapes the names of the model with backticks in an expression,
      # outside of string literals.
      def escape(text)
        return text if @names.empty?

        @pattern ||= Regexp.new("(?<![\\w`])(#{@names.map { |name| Regexp.escape(name) }.join("|")})(?![\\w`])")
        text.split(/("(?:[^"\\]|\\.)*")/).each_with_index.map do |part, index|
          index.odd? ? part : part.gsub(@pattern) { "`#{Regexp.last_match(1)}`" }
        end.join
      end

      def decision_by_name(name)
        @decisions.values.find { |el| el["name"] == name }
      end
    end

    # Evaluates the decisions of a model for the inputs of a test case.
    class Evaluator
      EXPRESSIONS = %w[literalExpression context invocation list relation functionDefinition conditional filter for some every decisionTable].freeze

      def initialize(model, inputs)
        @model = model
        @inputs = inputs
        @values = {}
        @functions = {}
      end

      def decision(el)
        id = el["id"] || el["name"]
        return @values[id] if @values.key?(id)
        return @values[id] = @inputs[el["name"]] if @inputs.key?(el["name"])

        variables = @inputs.dup
        requirements(el, variables)
        expression = expression_of(el)
        raise Unsupported, "decision without logic" unless expression

        @values[id] = evaluate(feel(expression), variables)
      end

      private

      def requirements(el, variables)
        el.xpath("informationRequirement/requiredDecision | informationRequirement/requiredInput").each do |requirement|
          id = requirement["href"].sub(/\A.*#/, "")
          if (decision = @model.decisions[id])
            variables[decision["name"]] = decision(decision)
          elsif @model.inputs.key?(id)
            name = @model.inputs[id]
            variables[name] = @inputs[name] unless variables.key?(name)
          else
            raise Unsupported, "requirement #{id}"
          end
        end
        el.xpath("knowledgeRequirement/requiredKnowledge").each do |requirement|
          id = requirement["href"].sub(/\A.*#/, "")
          raise Unsupported, "decision service" if @model.services.key?(id)
          raise Unsupported, "knowledge requirement #{id}" unless (bkm = @model.bkms[id])

          variables[bkm["name"]] = bkm(bkm)
        end
      end

      # A BKM as a FEEL function (a context entry, so that it can call itself).
      def bkm(el)
        @functions[el["id"] || el["name"]] ||= begin
          logic = el.at_xpath("encapsulatedLogic")
          raise Unsupported, "BKM without logic" unless logic
          raise Unsupported, "function kind #{logic["kind"]}" if logic["kind"] && logic["kind"] != "FEEL"

          variables = {}
          requirements(el, variables)
          params = logic.xpath("formalParameter").map { |parameter| name(parameter["name"]) }
          body = expression_of(logic)
          text = "{#{key(el["name"])}: function(#{params.join(", ")}) #{body ? paren(feel(body)) : "null"}}.#{name(el["name"])}"
          evaluate(text, variables)
        end
      end

      def evaluate(text, variables)
        FEEL.compile(text).tree.compiled.call(RootScope.build(variables))
      end

      def expression_of(el)
        el.element_children.find { |child| EXPRESSIONS.include?(child.name) }
      end

      def paren(text)
        "(#{text}\n)"
      end

      def key(name)
        name.inspect
      end

      def name(name)
        name.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) ? name : "`#{name}`"
      end

      def child(el, name)
        expression = expression_of(el.at_xpath(name))
        expression ? paren(feel(expression)) : "null"
      end

      def feel(el)
        case el.name
        when "literalExpression", "inputExpression"
          text = el.at_xpath("text")&.text.to_s.strip
          text.empty? ? "null" : @model.escape(text)
        when "context" then context(el)
        when "invocation"
          callee = el.element_children.find { |child| child.name == "literalExpression" }
          bindings = el.xpath("binding").map do |binding|
            expression = expression_of(binding)
            "#{name(binding.at_xpath("parameter")["name"])}: #{expression ? paren(feel(expression)) : "null"}"
          end
          "#{feel(callee)}(#{bindings.join(", ")})"
        when "list"
          "[#{el.element_children.select { |item| EXPRESSIONS.include?(item.name) }.map { |item| paren(feel(item)) }.join(", ")}]"
        when "relation"
          columns = el.xpath("column").map { |column| column["name"] }
          rows = el.xpath("row").map do |row|
            cells = row.element_children.select { |cell| EXPRESSIONS.include?(cell.name) }
            "{#{columns.zip(cells).map { |column, cell| "#{key(column)}: #{paren(feel(cell))}" }.join(", ")}}"
          end
          "[#{rows.join(", ")}]"
        when "functionDefinition"
          raise Unsupported, "function kind #{el["kind"]}" if el["kind"] && el["kind"] != "FEEL"

          params = el.xpath("formalParameter").map { |parameter| name(parameter["name"]) }
          body = expression_of(el)
          "function(#{params.join(", ")}) #{body ? paren(feel(body)) : "null"}"
        # The boxed expressions of DMN 1.5 result in null for a non-boolean
        # condition (unlike the FEEL `if`, which takes the `else` branch).
        when "conditional"
          "{\"c\": #{child(el, "if")}, \"r\": if c = true then #{child(el, "then")} " \
            "else if c = false or c = null then #{child(el, "else")} else null}.r"
        when "filter"
          match = child(el, "match")
          "{\"l\": #{child(el, "in")}, \"m\": for item in l return #{match}, " \
            "\"r\": if every x in m satisfies (x = true or x = false or x = null) then l[#{match}] else null}.r"
        when "for"
          "for #{name(el["iteratorVariable"])} in #{child(el, "in")} return #{child(el, "return")}"
        when "some", "every"
          "{\"v\": for #{name(el["iteratorVariable"])} in #{child(el, "in")} return #{child(el, "satisfies")}, " \
            "\"r\": if every x in v satisfies (x = true or x = false or x = null) then #{el.name == "some" ? "any" : "all"}(v) else null}.r"
        when "decisionTable" then decision_table(el)
        else raise Unsupported, el.name
        end
      end

      # A context, with its result entry (an entry without a name), if any.
      def context(el)
        result = nil
        entries = el.xpath("contextEntry").filter_map do |entry|
          expression = expression_of(entry)
          value = expression ? paren(feel(expression)) : "null"
          variable = entry.at_xpath("variable")
          unless variable
            result = value
            next
          end

          "#{key(variable["name"])}: #{value}"
        end
        return "{#{entries.join(", ")}}" unless result

        "{#{(entries + ["\"__result\": #{result}"]).join(", ")}}.__result"
      end

      # A decision table as a FEEL expression: the rules (match and output)
      # are a list of contexts, then the hit policy selects the result.
      def decision_table(el)
        inputs = el.xpath("input").map { |input| feel(input.at_xpath("inputExpression")) }
        outputs = el.xpath("output")
        rules = el.xpath("rule").map do |rule|
          conditions = rule.xpath("inputEntry").each_with_index.filter_map do |entry, index|
            test = @model.escape(entry.at_xpath("text").text.strip)
            next if test.empty? || test == "-"

            input = paren(inputs[index])
            test.start_with?("not(") && test.end_with?(")") ? "not(#{input} in (#{test[4...-1]}))" : "#{input} in (#{test})"
          end
          match = conditions.empty? ? "true" : conditions.map { |condition| paren(condition) }.join(" and ")
          values = rule.xpath("outputEntry").map { |entry| entry.at_xpath("text").text.strip.then { |text| text.empty? ? "null" : @model.escape(text) } }
          "{\"m\": (#{match}\n) = true, \"o\": #{output_value(outputs, values)}}"
        end

        defaults = outputs.map { |output| output.at_xpath("defaultOutputEntry/text")&.text&.strip }
        default = defaults.any? ? output_value(outputs, defaults.map { |text| text.nil? || text.empty? ? "null" : text }) : "null"
        "{\"__rules\": [#{rules.join(", ")}], \"__hits\": __rules[item.m].o, \"__result\": #{hit_policy(el, outputs, default)}}.__result"
      end

      def hit_policy(el, outputs, default)
        aggregation = el["aggregation"]&.upcase
        case (el["hitPolicy"] || "UNIQUE").upcase
        when "UNIQUE" then "if count(__hits) = 1 then __hits[1] else if count(__hits) = 0 then #{default} else null"
        when "FIRST" then "if count(__hits) = 0 then #{default} else __hits[1]"
        when "ANY" then "if count(__hits) = 0 then #{default} else if count(distinct values(__hits)) = 1 then __hits[1] else null"
        when "PRIORITY" then "if count(__hits) = 0 then #{default} else #{priority_sort(outputs, "__hits")}[1]"
        when "OUTPUT ORDER" then priority_sort(outputs, "__hits")
        when "RULE ORDER" then "__hits"
        when "COLLECT"
          case aggregation
          when nil then "__hits"
          when "SUM" then "if count(__hits) = 0 then #{default} else sum(__hits)"
          when "COUNT" then "count(__hits)"
          when "MIN" then "if count(__hits) = 0 then #{default} else min(__hits)"
          when "MAX" then "if count(__hits) = 0 then #{default} else max(__hits)"
          else raise Unsupported, "aggregation #{aggregation}"
          end
        else raise Unsupported, "hit policy #{el["hitPolicy"]}"
        end
      end

      def output_value(outputs, values)
        return paren(values.first) if outputs.size == 1

        "{#{outputs.zip(values).map { |output, value| "#{key(output["name"])}: #{paren(value)}" }.join(", ")}}"
      end

      # Sorts the hits by the order of the output values (priority), from
      # the outputs or their types.
      def priority_sort(outputs, hits)
        ranks = outputs.map do |output|
          values = output.at_xpath("outputValues/text")&.text&.strip
          values = @model.item_definitions[output["typeRef"]]&.at_xpath("allowedValues/text")&.text&.strip if values.nil? || values.empty?
          raise Unsupported, "priority without output values" if values.nil? || values.empty?

          "index of([#{values}], #{outputs.size == 1 ? "x" : "x.#{name(output["name"])}"})[1]"
        end
        rank = ranks.each_with_index.map { |r, index| "(#{r}) * #{10**(3 * (ranks.size - 1 - index))}" }.join(" + ")
        "sort(#{hits}, function(a, b) {\"x\": a, \"r\": #{rank}}.r < {\"x\": b, \"r\": #{rank}}.r)"
      end
    end

    module_function

    # Runs the test cases in `root` (the TestCases directory of the TCK).
    def run(root, filter: nil)
      Dir[File.join(root, "compliance-level-{2,3}", "*")].select { |dir| File.directory?(dir) }.sort.flat_map do |dir|
        next [] if filter && !dir.include?(filter)

        Dir[File.join(dir, "*-test-*.xml")].sort.flat_map { |file| run_file(root, dir, file) }
      end
    end

    def run_file(root, dir, file)
      folder = dir.delete_prefix("#{root}/")
      name = File.basename(file, ".xml")
      doc = Nokogiri::XML(File.read(file))
      doc.remove_namespaces!
      model = begin
        Model.new(File.join(dir, doc.at_xpath("//modelName").text.strip))
      rescue Unsupported, Errno::ENOENT => e
        e
      end

      doc.xpath("//testCase").map do |test_case|
        status, details = run_test_case(model, test_case)
        Result.new(folder, name, test_case["id"], status, details)
      end
    end

    def run_test_case(model, test_case)
      return ["UNSUPPORTED", model.message] if model.is_a?(Exception)
      return ["UNSUPPORTED", "decision service invocation"] if test_case["invocableName"] || test_case["type"] == "decisionService"

      inputs = test_case.xpath("inputNode").to_h { |node| [node["name"], parse_value(node)] }
      evaluator = Evaluator.new(model, inputs)
      status = "SUCCESS"
      details = []
      test_case.xpath("resultNode").each do |node|
        expected = parse_value(node.at_xpath("expected"))
        error_result = node["errorResult"] == "true"
        begin
          decision = model.decision_by_name(node["name"])
          raise Unsupported, "result node #{node["name"]}" unless decision

          actual = evaluator.decision(decision)
          next if (error_result && actual.nil?) || same?(expected, actual)

          status = "FAILURE" if status == "SUCCESS"
          details << "#{node["name"]}: expected #{describe(expected)}, got #{describe(actual)}"
        rescue Unsupported => e
          status = "UNSUPPORTED"
          details << e.message
        rescue FEEL::SyntaxError => e
          # the expressions of the TCK are valid: not an expected error
          status = "ERROR" unless status == "UNSUPPORTED"
          details << "#{node["name"]}: #{e.message[0, 200]}"
        rescue StandardError, SystemStackError => e
          next if error_result

          status = "ERROR" unless status == "UNSUPPORTED"
          details << "#{node["name"]}: #{e.class.name.split("::").last} #{e.message[0, 200]}"
        end
      end
      [status, details.join(" | ")]
    end

    # A value of a test case: a value, a list or a context (components).
    def parse_value(el)
      return nil if el.nil?

      if (value = el.at_xpath("value"))
        value["nil"] == "true" ? nil : scalar(value)
      elsif (list = el.at_xpath("list"))
        list["nil"] == "true" ? nil : list.xpath("item").map { |item| parse_value(item) }
      elsif el.xpath("component").any?
        el.xpath("component").to_h { |component| [component["name"], parse_value(component)] }
      end
    end

    def scalar(value)
      text = value.text.strip
      case value["type"].to_s.sub(/\A.*:/, "")
      when "decimal", "double", "integer", "long", "int"
        number = BigDecimal(text)
        number.frac.zero? ? number.to_i : number
      when "boolean" then text == "true"
      when "date" then FEEL.evaluate("date(#{text.inspect})") || text
      when "dateTime" then FEEL.evaluate("date and time(#{text.inspect})") || text
      when "time" then FEEL.evaluate("time(#{text.inspect})") || text
      when "duration" then FEEL.evaluate("duration(#{text.inspect})") || text
      else value.text
      end
    rescue ArgumentError
      text
    end

    VALUES = Object.new.extend(Values)

    # Compares as the TCK runners: numbers with a difference below 0.00000001.
    def same?(expected, actual)
      return actual.nil? if expected.nil?
      return false if actual.nil?

      case expected
      when Array then actual.is_a?(Array) && actual.size == expected.size && expected.zip(actual).all? { |e, a| same?(e, a) }
      when Hash
        actual = actual.to_h.transform_keys(&:to_s) if actual.is_a?(Hash) || actual.is_a?(Scope)
        actual.is_a?(Hash) && actual.keys.sort == expected.keys.sort && expected.all? { |k, v| same?(v, actual[k]) }
      when Integer, BigDecimal
        Numbers.number?(actual) && (Numbers.decimal(actual) - expected).abs < BigDecimal("0.00000001")
      when true, false, String then actual == expected
      else VALUES.feel_equal(expected, actual) == true
      end
    rescue StandardError
      false
    end

    def describe(value)
      Builtins::ConversionFormat.to_feel_string(value, nested: true)[0, 150]
    rescue StandardError
      value.inspect[0, 150]
    end
  end
end
