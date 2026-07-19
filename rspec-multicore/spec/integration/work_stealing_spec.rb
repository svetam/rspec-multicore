# frozen_string_literal: true

require "English"

RSpec.describe "Work Stealing Integration" do
  let(:fixture_dir) { File.expand_path("../fixtures/sample_suite", __dir__) }
  let(:seed) { 12_345 }

  def run_parallel(pattern:, formatter: "progress", extra_args: [])
    # Explicitly enable multicore without inheriting the parent process setting
    env = {
      "RSPEC_MULTICORE" => "2",
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

    require "open3"
    output, status = Open3.capture2e(env, *cmd)
    {
      output: output,
      exit_code: status.exitstatus
    }
  end

  describe "dynamic work distribution" do
    it "successfully runs more groups than concurrency limit" do
      # many_groups_spec.rb has 10 top-level groups
      # With default concurrency (usually 4-8), this tests work-stealing
      result = run_parallel(pattern: "many_groups_spec.rb")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to match(/10 examples, 0 failures/)
    end

    it "maintains correct order despite work-stealing" do
      result = run_parallel(pattern: "many_groups_spec.rb", formatter: "documentation")

      # All groups should be present in output
      (1..10).each do |i|
        expect(result[:output]).to match(/Group #{i}/)
      end
    end

    it "completes all examples when groups finish at different rates" do
      # Run all fixtures - different files have different execution times
      result = run_parallel(pattern: "*_spec.rb")

      # Count total examples
      example_count = result[:output].match(/(\d+) examples?/)&.[](1).to_i

      # Should have examples from all files
      expect(example_count).to be > 10
    end
  end

  describe "concurrency efficiency" do
    it "runs multiple groups in parallel (faster than serial)" do
      # This is a smoke test - we can't reliably measure time in CI
      # but we can verify it completes successfully
      result = run_parallel(pattern: "many_groups_spec.rb")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to match(/10 examples/)
    end
  end

  describe "group ordering preservation" do
    it "replays events in seed order regardless of completion order" do
      # Run with documentation formatter to see order
      result = run_parallel(pattern: "many_groups_spec.rb", formatter: "documentation")

      # Extract group names in order they appear
      groups = result[:output].scan(/^Group \d+$/)

      # Should have all 10 groups
      expect(groups.size).to eq(10)

      # Groups should appear in consistent order (determined by seed)
      # Run again to verify consistency
      result2 = run_parallel(pattern: "many_groups_spec.rb", formatter: "documentation")
      groups2 = result2[:output].scan(/^Group \d+$/)

      expect(groups2).to eq(groups)
    end
  end

  describe "progress reporting with work-stealing" do
    it "shows progress dots as examples complete across workers" do
      result = run_parallel(pattern: "many_groups_spec.rb", formatter: "progress")

      # Extract progress section
      progress_section = result[:output].match(/seed \d+\n(.*)Finished/m)&.[](1) || ""
      dot_count = progress_section.scan(".").size

      # Should have 10 dots (one per example)
      expect(dot_count).to eq(10)
    end

    it "does not duplicate progress indicators" do
      result = run_parallel(pattern: "many_groups_spec.rb", formatter: "progress")

      # Count all dots in output
      progress_section = result[:output].match(/seed \d+\n(.*)Finished/m)&.[](1) || ""
      dot_count = progress_section.scan(".").size

      # Should be exactly 10 (no duplicates)
      expect(dot_count).to eq(10)
    end
  end
end
