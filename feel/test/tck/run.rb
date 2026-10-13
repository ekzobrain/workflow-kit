# frozen_string_literal: true

# Runs the DMN TCK test cases (see README.md) and compares the failures with
# expected_failures.txt: fails if a test case fails that isn't listed there (a
# regression), or if a listed one passes (to be removed from the list).
#
#   ruby -Ilib test/tck/run.rb [--accept] [filter]
#
# --accept rewrites expected_failures.txt with the current failures.

require_relative "runner"

root = File.expand_path("cases", __dir__)
expected_file = File.expand_path("expected_failures.txt", __dir__)
accept = ARGV.delete("--accept")
filter = ARGV.first

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
results = FEEL::TCK.run(root, filter: filter)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

report = File.expand_path("../../tmp/tck_results.tsv", __dir__)
Dir.mkdir(File.dirname(report)) unless Dir.exist?(File.dirname(report))
File.write(report, results.map { |r| [r.folder, r.file, r.id, r.status, r.details].join("\t").gsub("\n", " ") }.join("\n") + "\n")

counts = results.map(&:status).tally
puts format("DMN TCK (revision %s): %d test cases in %.1fs - %s",
  File.read(File.join(root, "REVISION")).strip[0, 12], results.size, elapsed,
  %w[SUCCESS FAILURE ERROR UNSUPPORTED].map { |status| "#{counts.fetch(status, 0)} #{status.downcase}" }.join(", "))
puts "Report: #{report}"

failing = results.reject { |result| result.status == "SUCCESS" }
if accept
  abort "--accept needs a run of all the test cases (no filter)" if filter
  File.write(expected_file, <<~HEADER + failing.map { |r| "#{r.key}  # #{r.status}: #{r.details.gsub(/\s+/, " ")[0, 160]}" }.join("\n") + "\n")
    # The DMN TCK test cases that are expected to fail (see README.md), with
    # the reason. Regenerate with: rake tck:accept
  HEADER
  puts "#{expected_file}: #{failing.size} expected failures"
  exit
end

expected = File.readlines(expected_file).reject { |line| line.start_with?("#") }.map { |line| line.split("  # ").first.strip }.reject(&:empty?).to_set
regressions = failing.reject { |result| expected.include?(result.key) }
fixed = results.select { |result| result.status == "SUCCESS" && expected.include?(result.key) }

regressions.each { |r| puts "REGRESSION #{r.key}: #{r.status} #{r.details}" }
fixed.each { |r| puts "FIXED      #{r.key} (remove it from expected_failures.txt: rake tck:accept)" }
exit(regressions.empty? && fixed.empty? ? 0 : 1)
