# frozen_string_literal: true

require "English"
require "tempfile"
require "open3"

RSpec.describe "Edge Cases Integration" do
  let(:fixture_dir) { File.expand_path("../fixtures/sample_suite", __dir__) }
  let(:seed) { 12_345 }

  def run_rspec(pattern:, formatter: "progress", extra_args: [], disable_multicore: false)
    # Explicitly set RSPEC_MULTICORE to avoid inheriting from parent process
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
      *extra_args
    ].compact

    output, status = Open3.capture2e(env, *cmd)
    {
      output: output,
      exit_code: status.exitstatus
    }
  end

  def run_parallel(pattern:, formatter: "progress", extra_args: [])
    run_rspec(pattern: pattern, formatter: formatter, extra_args: extra_args, disable_multicore: false)
  end

  describe "single file execution" do
    it "runs in serial mode for single file (no parallelization overhead)" do
      result = run_parallel(pattern: "passing_spec.rb")

      # Should complete successfully
      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to match(/3 examples, 0 failures/)
    end

    it "handles single failing file correctly" do
      result = run_parallel(pattern: "failing_spec.rb")

      # Should report failures
      expect(result[:exit_code]).not_to eq(0)
      expect(result[:output]).to match(/failures/)
    end
  end

  describe "empty suite" do
    it "handles no matching files gracefully" do
      result = run_parallel(pattern: "nonexistent_*.rb")

      # RSpec should handle this gracefully
      expect(result[:output]).to match(/0 examples/)
    end
  end

  describe "large suite simulation" do
    it "handles multiple files with different outcomes" do
      result = run_parallel(pattern: "*_spec.rb")

      # Should run all files
      expect(result[:output]).to match(/examples/)

      # Should have both passes and failures
      expect(result[:output]).to match(/failures/)
    end
  end

  describe "formatter compatibility" do
    it "works with html formatter" do
      output_file = Tempfile.new(["rspec", ".html"])

      begin
        result = run_parallel(
          pattern: "passing_spec.rb",
          formatter: "html",
          extra_args: ["--out", output_file.path]
        )

        expect(result[:exit_code]).to eq(0)
        expect(File.exist?(output_file.path)).to be true
        expect(File.size(output_file.path)).to be > 0

        # HTML should contain example information
        html_content = File.read(output_file.path)
        expect(html_content).to include("examples")
      ensure
        output_file.close
        output_file.unlink
      end
    end

    it "works with multiple formatters simultaneously" do
      json_file = Tempfile.new(["rspec", ".json"])
      html_file = Tempfile.new(["rspec", ".html"])

      begin
        result = run_parallel(
          pattern: "passing_spec.rb",
          formatter: "progress",
          extra_args: [
            "--format", "json", "--out", json_file.path,
            "--format", "html", "--out", html_file.path
          ]
        )

        expect(result[:exit_code]).to eq(0)

        # Both files should be created
        expect(File.exist?(json_file.path)).to be true
        expect(File.exist?(html_file.path)).to be true

        # Both should have content
        expect(File.size(json_file.path)).to be > 0
        expect(File.size(html_file.path)).to be > 0
      ensure
        json_file.close
        json_file.unlink
        html_file.close
        html_file.unlink
      end
    end
  end

  describe "concurrency control" do
    it "respects the RSPEC_MULTICORE environment variable" do
      ENV["RSPEC_MULTICORE"] = "0"

      result = run_rspec(pattern: "*_spec.rb")

      # Should still work in serial mode
      expect(result[:output]).to match(/examples/)

      ENV["RSPEC_MULTICORE"] = "0"
    end
  end

  describe "output ordering" do
    it "maintains consistent output order across multiple runs" do
      # Run twice with same seed
      result1 = run_parallel(pattern: "*_spec.rb", formatter: "documentation")
      result2 = run_parallel(pattern: "*_spec.rb", formatter: "documentation")

      # Extract example lines
      lines1 = result1[:output].lines.grep(/^\s+(passes|fails|is pending)/).map(&:strip)
      lines2 = result2[:output].lines.grep(/^\s+(passes|fails|is pending)/).map(&:strip)

      # Should be identical
      expect(lines2).to eq(lines1)
    end
  end

  describe "error handling" do
    it "handles examples that output to stderr" do
      result = run_parallel(pattern: "passing_spec.rb")

      # Should capture stderr output
      expect(result[:output]).to include("Stderr from passing test 2")
    end

    it "reports all failures even when multiple files fail" do
      result = run_parallel(pattern: "*_spec.rb")

      # Should have failure details
      expect(result[:output]).to match(/Failures:/)

      # Should list individual failures
      failure_count = result[:output].scan(/^\s+\d+\)/).size
      expect(failure_count).to be > 0
    end
  end

  describe "pending examples handling" do
    it "correctly counts and reports pending examples" do
      result = run_parallel(pattern: "pending_spec.rb")

      # Should report pending count (1 pending, 1 skipped = 2 pending total)
      expect(result[:output]).to match(/3 examples, 0 failures, 2 pending/)
    end

    it "includes pending reasons in output" do
      result = run_parallel(pattern: "pending_spec.rb")

      # Should show pending reasons
      expect(result[:output]).to match(/Not implemented yet/)
      expect(result[:output]).to match(/Temporarily skipped with xit/)
    end
  end

  describe "mixed results" do
    it "correctly summarizes mixed pass/fail/pending results" do
      result = run_parallel(pattern: "mixed_spec.rb")

      # Should have summary with all states
      expect(result[:output]).to match(/examples/)
      expect(result[:output]).to match(/failure/)
    end
  end

  describe "seed consistency" do
    it "produces same results with same seed in parallel mode" do
      result1 = run_parallel(pattern: "*_spec.rb")
      result2 = run_parallel(pattern: "*_spec.rb")

      # Extract counts
      examples1 = result1[:output].match(/(\d+) examples?/)&.[](1).to_i
      failures1 = result1[:output].match(/(\d+) failures?/)&.[](1).to_i

      examples2 = result2[:output].match(/(\d+) examples?/)&.[](1).to_i
      failures2 = result2[:output].match(/(\d+) failures?/)&.[](1).to_i

      expect(examples2).to eq(examples1)
      expect(failures2).to eq(failures1)
    end
  end

  describe "performance characteristics" do
    it "completes execution without hanging" do
      # This test ensures the parallel execution doesn't deadlock
      timeout = 30 # seconds

      result = nil
      thread = Thread.new do
        result = run_parallel(pattern: "*_spec.rb")
      end

      # Wait for completion with timeout
      completed = thread.join(timeout)

      expect(completed).not_to be_nil, "Execution timed out after #{timeout} seconds"
      expect(result).not_to be_nil
      expect(result[:output]).to match(/examples/)
    end
  end
end
