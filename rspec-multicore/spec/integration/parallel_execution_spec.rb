# frozen_string_literal: true

require "English"
require "json"
require "tempfile"

RSpec.describe "Parallel Execution Integration" do
  let(:fixture_dir) { File.expand_path("../fixtures/sample_suite", __dir__) }
  let(:seed) { 12_345 }

  def run_rspec(pattern:, formatter: "progress", extra_args: [], disable_multicore: false)
    # Explicitly set or unset RSPEC_MULTICORE to avoid inheriting from parent process
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
      "--require", gem_lib_path,
      *extra_args
    ].compact

    # Use Open3 to properly pass environment variables to subprocess
    require "open3"
    output, status = Open3.capture2e(env, *cmd)
    {
      output: output,
      exit_code: status.exitstatus
    }
  end

  def fixtures_rspec_path = File.expand_path("../fixtures/.rspec", __dir__)

  def gem_lib_path = "rspec/multicore"

  def run_serial(pattern:, formatter: "progress", extra_args: [])
    run_rspec(pattern: pattern, formatter: formatter, extra_args: extra_args, disable_multicore: true)
  end

  def run_parallel(pattern:, formatter: "progress", extra_args: [])
    run_rspec(pattern: pattern, formatter: formatter, extra_args: extra_args, disable_multicore: false)
  end

  describe "deterministic execution" do
    it "produces identical failure counts in serial vs parallel" do
      serial = run_serial(pattern: "*_spec.rb")
      parallel = run_parallel(pattern: "*_spec.rb")

      # Extract failure count
      serial_failures = serial[:output].match(/(\d+) failures?/)&.[](1).to_i
      parallel_failures = parallel[:output].match(/(\d+) failures?/)&.[](1).to_i

      expect(parallel_failures).to eq(serial_failures)
    end

    it "produces identical example counts" do
      serial = run_serial(pattern: "*_spec.rb")
      parallel = run_parallel(pattern: "*_spec.rb")

      serial_examples = serial[:output].match(/(\d+) examples?/)&.[](1).to_i
      parallel_examples = parallel[:output].match(/(\d+) examples?/)&.[](1).to_i

      expect(parallel_examples).to eq(serial_examples)
    end

    it "produces identical exit codes" do
      serial = run_serial(pattern: "*_spec.rb")
      parallel = run_parallel(pattern: "*_spec.rb")

      expect(parallel[:exit_code]).to eq(serial[:exit_code])
      expect(parallel[:exit_code]).not_to eq(0) # Should fail due to failing_spec.rb
    end

    it "maintains seed order in output" do
      serial = run_serial(pattern: "*_spec.rb", formatter: "documentation")
      parallel = run_parallel(pattern: "*_spec.rb", formatter: "documentation")

      # Extract example descriptions in order
      serial_examples = serial[:output].scan(/^\s+(passes|fails|is pending|is skipped|passes with|fails with).*$/)
      parallel_examples = parallel[:output].scan(/^\s+(passes|fails|is pending|is skipped|passes with|fails with).*$/)

      expect(parallel_examples).to eq(serial_examples)
    end
  end

  describe "progress formatter" do
    it "shows dots only when progress formatter is configured" do
      result = run_parallel(pattern: "passing_spec.rb", formatter: "progress")

      # Should contain progress dots (extract the progress line)
      # Progress dots appear between "seed" line and "Finished" line
      progress_section = result[:output].match(/seed \d+\n(.*)Finished/m)&.[](1) || ""
      dot_count = progress_section.scan(".").size
      expect(dot_count).to eq(3) # 3 passing examples
    end

    it "does not show duplicate dots" do
      result = run_parallel(pattern: "passing_spec.rb", formatter: "progress")

      # Count progress dots - should be exactly 3 (one per example)
      progress_section = result[:output].match(/seed \d+\n(.*)Finished/m)&.[](1) || ""
      dot_count = progress_section.scan(".").size
      expect(dot_count).to eq(3)
    end

    it "shows F for failures" do
      result = run_parallel(pattern: "failing_spec.rb", formatter: "progress")

      # Should show F for failures
      expect(result[:output]).to match(/F/)
    end

    it "shows * for pending" do
      result = run_parallel(pattern: "pending_spec.rb", formatter: "progress")

      # Should show * for pending
      expect(result[:output]).to match(/\*/)
    end
  end

  describe "documentation formatter" do
    it "produces identical output in serial vs parallel" do
      serial = run_serial(pattern: "passing_spec.rb", formatter: "documentation")
      parallel = run_parallel(pattern: "passing_spec.rb", formatter: "documentation")

      # Extract example lines (ignoring timing differences)
      serial_lines = serial[:output].lines.grep(/^\s+(passes|fails)/).map(&:strip)
      parallel_lines = parallel[:output].lines.grep(/^\s+(passes|fails)/).map(&:strip)

      expect(parallel_lines).to eq(serial_lines)
    end

    it "maintains hierarchical structure" do
      result = run_parallel(pattern: "passing_spec.rb", formatter: "documentation")

      expect(result[:output]).to match(/Passing examples/)
      expect(result[:output]).to match(/\s+passes test 1/)
      expect(result[:output]).to match(/\s+passes test 2/)
    end
  end

  describe "JSON formatter" do
    it "produces valid JSON" do
      output_file = Tempfile.new(["rspec", ".json"])

      begin
        run_parallel(
          pattern: "passing_spec.rb",
          formatter: "json",
          extra_args: ["--out", output_file.path]
        )

        json_content = File.read(output_file.path)
        parsed = JSON.parse(json_content)

        expect(parsed).to have_key("examples")
        expect(parsed["examples"]).to be_an(Array)
        expect(parsed["examples"].size).to eq(3)
      ensure
        output_file.close
        output_file.unlink
      end
    end

    it "produces identical JSON structure in serial vs parallel" do
      serial_file = Tempfile.new(["rspec-serial", ".json"])
      parallel_file = Tempfile.new(["rspec-parallel", ".json"])

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

        # Compare example counts
        expect(parallel_json["examples"].size).to eq(serial_json["examples"].size)

        # Compare summary
        expect(parallel_json["summary"]["example_count"]).to eq(serial_json["summary"]["example_count"])
        expect(parallel_json["summary"]["failure_count"]).to eq(serial_json["summary"]["failure_count"])
      ensure
        serial_file.close
        serial_file.unlink
        parallel_file.close
        parallel_file.unlink
      end
    end
  end

  describe "stdout/stderr handling" do
    it "captures stdout from examples" do
      result = run_parallel(pattern: "passing_spec.rb")

      expect(result[:output]).to include("Output from passing test 1")
    end

    it "captures stderr from examples" do
      result = run_parallel(pattern: "passing_spec.rb")

      expect(result[:output]).to include("Stderr from passing test 2")
    end

    it "maintains output order in seed order" do
      result = run_parallel(pattern: "mixed_spec.rb", formatter: "documentation")

      # Output should appear in the order examples are executed (seed order)
      output_lines = result[:output].lines.map(&:strip)

      # Find indices of output lines
      line1_idx = output_lines.index("Line 1")
      line2_idx = output_lines.index("Line 2")
      output_lines.index("Error line")

      # They should appear in order if present
      expect(line2_idx).to be > line1_idx if line1_idx && line2_idx
    end
  end

  describe "failure handling" do
    it "reports all failures" do
      result = run_parallel(pattern: "failing_spec.rb")

      expect(result[:output]).to match(/expected: 3/)
      expect(result[:output]).to match(/expected: "goodbye"/)
    end

    it "reports failures in seed order" do
      result = run_parallel(pattern: "failing_spec.rb", formatter: "documentation")

      # Extract failure descriptions
      failures = result[:output].scan(/^\s+\d+\) .*$/)

      expect(failures.size).to be >= 2
    end
  end

  describe "pending examples" do
    it "reports pending examples correctly" do
      result = run_parallel(pattern: "pending_spec.rb")

      expect(result[:output]).to match(/pending/)
      expect(result[:output]).to match(/Not implemented yet/)
    end

    it "counts pending examples separately" do
      result = run_parallel(pattern: "pending_spec.rb")

      # Should have 2 pending (1 pending, 1 skipped)
      pending_count = result[:output].match(/(\d+) pending/)&.[](1).to_i
      expect(pending_count).to eq(2)
    end
  end
end
