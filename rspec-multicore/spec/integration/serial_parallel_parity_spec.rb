# frozen_string_literal: true

require "English"
require "json"
require "tempfile"

# Module-level cache for memoizing RSpec run results across examples
module ParityTestCache
  @results = {}

  class << self
    def fetch(key) = @results[key]

    def store(key, value) = @results[key] = value

    def clear = @results.clear
  end
end

RSpec.describe "Serial vs Parallel Parity" do
  let(:fixture_dir) { File.expand_path("../fixtures/sample_suite", __dir__) }
  let(:seed) { 54_321 }

  def run_rspec(pattern:, formatter: "progress", extra_args: [], disable_multicore: false)
    cache_key = [pattern, formatter, extra_args, disable_multicore]

    # Return cached result if available (significant speedup)
    cached = ParityTestCache.fetch(cache_key)
    return cached if cached

    env = {
      "RSPEC_MULTICORE" => (disable_multicore ? "0" : "2"),
      "SPEC" => nil,
      "SPEC_OPTS" => nil
    }
    cmd = [
      "bundle", "exec", "rspec",
      "--pattern", "#{fixture_dir}/#{pattern}",
      "--format", formatter,
      "--seed", seed.to_s,
      "--order", "rand:#{seed}",
      "--options", fixtures_rspec_path,
      "--require", "rspec/multicore",
      *extra_args
    ].compact

    require "open3"
    output, status = Open3.capture2e(env, *cmd)
    result = { output: output, exit_code: status.exitstatus }

    # Cache the result
    ParityTestCache.store(cache_key, result)
    result
  end

  def fixtures_rspec_path = File.expand_path("../fixtures/.rspec", __dir__)

  def run_serial(pattern:, formatter: "progress", extra_args: [])
    run_rspec(pattern: pattern, formatter: formatter, extra_args: extra_args, disable_multicore: true)
  end

  def run_parallel(pattern:, formatter: "progress", extra_args: [])
    run_rspec(pattern: pattern, formatter: formatter, extra_args: extra_args, disable_multicore: false)
  end

  def extract_counts(output)
    examples = output.match(/(\d+) examples?/)&.[](1).to_i
    failures = output.match(/(\d+) failures?/)&.[](1).to_i
    pending = output.match(/(\d+) pending/)&.[](1).to_i
    { examples: examples, failures: failures, pending: pending }
  end

  # Combines pattern with passing_spec.rb to ensure 2+ groups for parallelization
  def multi_group_pattern(pattern)
    return pattern if pattern.include?("{") || pattern.include?("*")

    "{#{pattern},passing_spec.rb}"
  end

  # Optimized: single test with all parity assertions (avoids 4x subprocess overhead)
  shared_examples "serial parallel parity" do |pattern|
    it "has identical counts and exit code for #{pattern}" do
      test_pattern = multi_group_pattern(pattern)
      serial = run_serial(pattern: test_pattern)
      parallel = run_parallel(pattern: test_pattern)

      serial_counts = extract_counts(serial[:output])
      parallel_counts = extract_counts(parallel[:output])

      aggregate_failures do
        examples_message = "Expected #{serial_counts[:examples]} examples, got #{parallel_counts[:examples]}"
        failures_message = "Expected #{serial_counts[:failures]} failures, got #{parallel_counts[:failures]}"
        pending_message = "Expected #{serial_counts[:pending]} pending, got #{parallel_counts[:pending]}"
        expect(parallel_counts[:examples]).to eq(serial_counts[:examples]),
                                              examples_message
        expect(parallel_counts[:failures]).to eq(serial_counts[:failures]),
                                              failures_message
        expect(parallel_counts[:pending]).to eq(serial_counts[:pending]),
                                             pending_message
        expect(parallel[:exit_code]).to eq(serial[:exit_code]),
                                        "Expected exit code #{serial[:exit_code]}, got #{parallel[:exit_code]}"
      end
    end
  end

  describe "nested structures" do
    include_examples "serial parallel parity", "nested_spec.rb"

    it "preserves nested describe output order" do
      serial = run_serial(pattern: "nested_spec.rb", formatter: "documentation")
      parallel = run_parallel(pattern: "nested_spec.rb", formatter: "documentation")

      serial_lines = serial[:output].lines.grep(/passes/).map(&:strip)
      parallel_lines = parallel[:output].lines.grep(/passes/).map(&:strip)

      expect(parallel_lines).to eq(serial_lines)
    end
  end

  describe "hooks behavior" do
    include_examples "serial parallel parity", "hooks_spec.rb"

    it "executes before/after hooks correctly" do
      parallel = run_parallel(pattern: "hooks_spec.rb")

      expect(parallel[:output]).to include("After each:")
      expect(parallel[:output]).to include("After all completed")
    end
  end

  describe "let and subject" do
    include_examples "serial parallel parity", "let_subject_spec.rb"
  end

  describe "shared examples" do
    include_examples "serial parallel parity", "shared_examples_spec.rb"

    it "runs shared examples in both groups" do
      parallel = run_parallel(pattern: "shared_examples_spec.rb", formatter: "documentation")

      expect(parallel[:output]).to include("Array collection")
      expect(parallel[:output]).to include("Hash collection")
      expect(parallel[:output]).to include("responds to each")
    end
  end

  describe "exceptions" do
    include_examples "serial parallel parity", "exceptions_spec.rb"
  end

  describe "metadata" do
    include_examples "serial parallel parity", "metadata_spec.rb"
  end

  describe "aggregate failures" do
    include_examples "serial parallel parity", "aggregate_failures_spec.rb"
  end

  describe "around hooks" do
    include_examples "serial parallel parity", "around_hook_spec.rb"

    it "executes around hooks in correct order" do
      parallel = run_parallel(pattern: "around_hook_spec.rb")

      expect(parallel[:output]).to include("Before around:")
      expect(parallel[:output]).to include("After around:")
    end
  end

  describe "described_class" do
    include_examples "serial parallel parity", "described_class_spec.rb"
  end

  describe "mocks and doubles" do
    include_examples "serial parallel parity", "mocks_spec.rb"
  end

  describe "slow and fast groups" do
    include_examples "serial parallel parity", "slow_fast_spec.rb"
  end

  describe "helper methods" do
    include_examples "serial parallel parity", "helper_methods_spec.rb"
  end

  describe "custom matchers" do
    include_examples "serial parallel parity", "custom_matchers_spec.rb"
  end

  describe "multiline output" do
    include_examples "serial parallel parity", "multiline_output_spec.rb"

    it "captures all output lines" do
      parallel = run_parallel(pattern: "multiline_output_spec.rb")

      expect(parallel[:output]).to include("Line 1 from example 1")
      expect(parallel[:output]).to include("Line 2 from example 1")
      expect(parallel[:output]).to include("STDOUT: message 1")
      expect(parallel[:output]).to include("STDERR: message 1")
    end
  end

  describe "filtering with tags" do
    include_examples "serial parallel parity", "filtering_spec.rb"
  end

  describe "pending variations" do
    include_examples "serial parallel parity", "pending_variations_spec.rb"

    it "reports pending reasons correctly" do
      parallel = run_parallel(pattern: "pending_variations_spec.rb")

      expect(parallel[:output]).to match(/waiting for implementation|skipping this test/)
    end
  end

  describe "expect change matchers" do
    include_examples "serial parallel parity", "expect_change_spec.rb"
  end

  describe "output matchers" do
    include_examples "serial parallel parity", "output_matcher_spec.rb"
  end

  describe "compound matchers" do
    include_examples "serial parallel parity", "compound_matchers_spec.rb"
  end

  describe "single example group" do
    it "runs in serial mode (no parallelization)" do
      result = run_parallel(pattern: "single_example_spec.rb")

      expect(result[:exit_code]).to eq(0)
      counts = extract_counts(result[:output])
      expect(counts[:examples]).to eq(1)
    end
  end

  describe "empty groups" do
    include_examples "serial parallel parity", "empty_groups_spec.rb"
  end

  describe "full suite parity" do
    it "has identical counts for entire suite" do
      serial = run_serial(pattern: "*_spec.rb")
      parallel = run_parallel(pattern: "*_spec.rb")

      serial_counts = extract_counts(serial[:output])
      parallel_counts = extract_counts(parallel[:output])

      expect(parallel_counts[:examples]).to eq(serial_counts[:examples])
      expect(parallel_counts[:failures]).to eq(serial_counts[:failures])
      expect(parallel_counts[:pending]).to eq(serial_counts[:pending])
    end

    it "has identical exit code for entire suite" do
      serial = run_serial(pattern: "*_spec.rb")
      parallel = run_parallel(pattern: "*_spec.rb")

      expect(parallel[:exit_code]).to eq(serial[:exit_code])
    end
  end

  describe "JSON formatter parity" do
    it "produces identical example counts in JSON" do
      serial_file = Tempfile.new(["serial", ".json"])
      parallel_file = Tempfile.new(["parallel", ".json"])

      begin
        run_serial(
          pattern: "*_spec.rb",
          formatter: "json",
          extra_args: ["--out", serial_file.path]
        )

        run_parallel(
          pattern: "*_spec.rb",
          formatter: "json",
          extra_args: ["--out", parallel_file.path]
        )

        serial_json = JSON.parse(File.read(serial_file.path))
        parallel_json = JSON.parse(File.read(parallel_file.path))

        expect(parallel_json["summary"]["example_count"]).to eq(serial_json["summary"]["example_count"])
        expect(parallel_json["summary"]["failure_count"]).to eq(serial_json["summary"]["failure_count"])
        expect(parallel_json["summary"]["pending_count"]).to eq(serial_json["summary"]["pending_count"])
      ensure
        serial_file.close
        serial_file.unlink
        parallel_file.close
        parallel_file.unlink
      end
    end

    it "produces identical example statuses" do
      serial_file = Tempfile.new(["serial", ".json"])
      parallel_file = Tempfile.new(["parallel", ".json"])

      begin
        run_serial(
          pattern: "passing_spec.rb",
          formatter: "json",
          extra_args: ["--out", serial_file.path]
        )

        run_parallel(
          pattern: "passing_spec.rb",
          formatter: "json",
          extra_args: ["--out", parallel_file.path]
        )

        serial_json = JSON.parse(File.read(serial_file.path))
        parallel_json = JSON.parse(File.read(parallel_file.path))

        serial_statuses = serial_json["examples"].map { |e| e["status"] }.sort
        parallel_statuses = parallel_json["examples"].map { |e| e["status"] }.sort

        expect(parallel_statuses).to eq(serial_statuses)
      ensure
        serial_file.close
        serial_file.unlink
        parallel_file.close
        parallel_file.unlink
      end
    end
  end

  describe "documentation formatter parity" do
    it "produces same example descriptions" do
      serial = run_serial(pattern: "nested_spec.rb", formatter: "documentation")
      parallel = run_parallel(pattern: "nested_spec.rb", formatter: "documentation")

      serial_examples = serial[:output].scan(/^\s+passes.*$/).map(&:strip).sort
      parallel_examples = parallel[:output].scan(/^\s+passes.*$/).map(&:strip).sort

      expect(parallel_examples).to eq(serial_examples)
    end

    it "maintains group hierarchy" do
      serial = run_serial(pattern: "described_class_spec.rb", formatter: "documentation")
      parallel = run_parallel(pattern: "described_class_spec.rb", formatter: "documentation")

      # Extract only the group/describe names, ignoring timing and metadata lines
      serial_groups = serial[:output].lines
                                     .grep(/^Calculator|^  #/)
                                     .map(&:strip)
                                     .reject(&:empty?)
      parallel_groups = parallel[:output].lines
                                         .grep(/^Calculator|^  #/)
                                         .map(&:strip)
                                         .reject(&:empty?)

      expect(parallel_groups).to eq(serial_groups)
    end
  end

  describe "full reporter output parity", :slow do
    # These tests run MULTIPLE fixtures together to ensure 2+ top-level groups,
    # which triggers actual parallel execution. Single-file tests would both
    # run in serial mode since parallelization requires 2+ groups.

    # Pattern that matches multiple files with simple, predictable output
    let(:multi_file_pattern) { "{passing,nested}_spec.rb" }
    let(:mixed_pattern) { "{passing,failing,pending}_spec.rb" }

    def normalize_output(output)
      output
        .gsub(/\d+\.\d+ seconds?/, "X.XX seconds")          # Normalize timing
        .gsub(/\d+:\d+:\d+/, "HH:MM:SS")                    # Normalize time of day
        .gsub(/seed \d+/, "seed XXXXX")                     # Normalize seed display
        .gsub(/pid:\d+/, "pid:XXXXX")                       # Normalize PIDs (lowercase)
        .gsub(/PID: \d+/, "PID: XXXXX")                     # Normalize PIDs (uppercase from fixtures)
        .gsub(/0x[0-9a-f]+/, "0xXXXXXX")                    # Normalize object IDs
        .gsub(%r{/\S+/sample_suite/}, ".FIXTURES/")         # Normalize paths
        .gsub(/Finished in X\.XX seconds.*$/, "FINISHED")   # Normalize finish line
        .gsub(/Randomized with seed.*$/, "RANDOMIZED")      # Normalize randomized line
        .lines
        .reject { |line| line.strip.empty? }                # Remove blank lines
        .reject { |line| line.include?("pool.rb") }         # Remove parallel pool frames
        .reject { |line| line.include?("parallel_groups.rb") } # Remove parallel groups frames
        .reject { |line| line.include?("runner_patch.rb") } # Remove runner patch frames
        .reject { |line| line.include?("Kernel#fork") }     # Remove fork frames
        .map(&:rstrip) # Remove trailing whitespace
    end

    it "produces identical documentation output for multiple passing files" do
      serial = run_serial(pattern: multi_file_pattern, formatter: "documentation")
      parallel = run_parallel(pattern: multi_file_pattern, formatter: "documentation")

      serial_normalized = normalize_output(serial[:output])
      parallel_normalized = normalize_output(parallel[:output])
      difference = "Output differs:\nSerial:\n#{serial_normalized.join("\n")}\n\n" \
                   "Parallel:\n#{parallel_normalized.join("\n")}"

      expect(parallel_normalized).to eq(serial_normalized), difference
    end

    it "produces identical documentation output for mixed results" do
      serial = run_serial(pattern: mixed_pattern, formatter: "documentation")
      parallel = run_parallel(pattern: mixed_pattern, formatter: "documentation")

      serial_normalized = normalize_output(serial[:output])
      parallel_normalized = normalize_output(parallel[:output])
      difference = "Output differs:\nSerial:\n#{serial_normalized.join("\n")}\n\n" \
                   "Parallel:\n#{parallel_normalized.join("\n")}"

      expect(parallel_normalized).to eq(serial_normalized), difference
    end

    it "produces identical progress output for multiple files" do
      serial = run_serial(pattern: multi_file_pattern, formatter: "progress")
      parallel = run_parallel(pattern: multi_file_pattern, formatter: "progress")

      serial_normalized = normalize_output(serial[:output])
      parallel_normalized = normalize_output(parallel[:output])

      expect(parallel_normalized).to eq(serial_normalized)
    end

    it "produces identical JSON structure for multiple files" do
      serial_file = Tempfile.new(["serial", ".json"])
      parallel_file = Tempfile.new(["parallel", ".json"])

      begin
        run_serial(
          pattern: multi_file_pattern,
          formatter: "json",
          extra_args: ["--out", serial_file.path]
        )

        run_parallel(
          pattern: multi_file_pattern,
          formatter: "json",
          extra_args: ["--out", parallel_file.path]
        )

        serial_json = JSON.parse(File.read(serial_file.path))
        parallel_json = JSON.parse(File.read(parallel_file.path))

        # Compare examples array (normalized - remove timing, ids)
        normalize_example = lambda do |ex|
          {
            "description" => ex["description"],
            "full_description" => ex["full_description"],
            "status" => ex["status"]
          }
        end

        serial_examples = serial_json["examples"].map(&normalize_example).sort_by { |e| e["full_description"] }
        parallel_examples = parallel_json["examples"].map(&normalize_example).sort_by { |e| e["full_description"] }

        expect(parallel_examples).to eq(serial_examples)
      ensure
        serial_file.close
        serial_file.unlink
        parallel_file.close
        parallel_file.unlink
      end
    end

    it "produces identical full suite output" do
      # Run ALL fixtures to get comprehensive coverage
      serial = run_serial(pattern: "*_spec.rb", formatter: "documentation")
      parallel = run_parallel(pattern: "*_spec.rb", formatter: "documentation")

      serial_normalized = normalize_output(serial[:output])
      parallel_normalized = normalize_output(parallel[:output])

      expect(parallel_normalized).to eq(serial_normalized)
    end
  end
end
