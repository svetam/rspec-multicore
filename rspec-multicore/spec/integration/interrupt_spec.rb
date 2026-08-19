# frozen_string_literal: true

require "open3"
require "timeout"
require "tmpdir"

RSpec.describe "Interrupt handling" do
  def interrupt_fixture(long_running: false)
    example_body = long_running ? "loop { sleep 0.1 }" : "sleep 0.2"

    <<~RUBY
      RSpec::Multicore.on_worker_fork do
        File.write(File.join(ENV.fetch("INTERRUPT_DIR"), "worker-\#{Process.pid}"), "")
      end

      RSpec::Multicore.on_worker_shutdown do
        File.write(File.join(ENV.fetch("INTERRUPT_DIR"), "shutdown-\#{Process.pid}"), "")
      end

      4.times do |group|
        RSpec.describe "interrupt group \#{group}" do
          10.times do |example|
            it "runs example \#{example}" do
              File.open(File.join(ENV.fetch("INTERRUPT_DIR"), "group-\#{group}"), "a") do |file|
                file.puts(example)
              end
              #{example_body}
            end
          end
        end
      end
    RUBY
  end

  def start_interrupt_run(directory, long_running: false, process_group: false)
    spec_path = File.join(directory, "interrupt_fixture_spec.rb")
    File.write(spec_path, interrupt_fixture(long_running:))
    env = {
      "INTERRUPT_DIR" => directory,
      "RSPEC_MULTICORE" => "2",
      "SPEC" => nil,
      "SPEC_OPTS" => nil
    }
    command = [
      "bundle", "exec", "rspec", spec_path,
      "--options", File::NULL,
      "--format", "progress",
      "--require", "rspec/multicore"
    ]

    Open3.popen2e(env, *command, pgroup: process_group)
  end

  def wait_for_workers(directory)
    Timeout.timeout(5) do
      sleep 0.01 until Dir.glob(File.join(directory, "worker-*")).size == 2
    end
  end

  def wait_for_active_groups(directory)
    Timeout.timeout(5) do
      sleep 0.01 until Dir.glob(File.join(directory, "group-*")).size == 2
    end
  end

  def finish_run(output, thread)
    text = Timeout.timeout(5) { output.read }
    [text, thread.value]
  end

  def worker_pids(directory)
    Dir.glob(File.join(directory, "worker-*")).map { File.basename(_1).delete_prefix("worker-").to_i }
  end

  def expect_workers_reaped(pids)
    pids.each do |pid|
      expect { Process.kill(0, pid) }.to raise_error(Errno::ESRCH)
    end
  end

  it "gracefully stops every worker when only the parent receives SIGINT" do
    Dir.mktmpdir("multicore-interrupt") do |directory|
      stdin, output, thread = start_interrupt_run(directory)
      stdin.close
      wait_for_workers(directory)
      pids = worker_pids(directory)

      Process.kill("INT", thread.pid)
      text, status = finish_run(output, thread)

      expect(text).to include("RSpec is shutting down and will print the summary report")
      expect(text).to match(/Finished in/)
      expect(text).not_to include("An error occurred in RSpec::Multicore")
      expect(status.exitstatus).to eq(1)
      expect(Dir.glob(File.join(directory, "group-*")).size).to be <= 2
      expect(Dir.glob(File.join(directory, "shutdown-*")).size).to eq(2)
      expect_workers_reaped(pids)
    ensure
      Process.kill("KILL", thread.pid) if thread&.alive?
    end
  end

  it "treats process-group SIGINT delivery as one graceful interrupt" do
    Dir.mktmpdir("multicore-interrupt") do |directory|
      stdin, output, thread = start_interrupt_run(directory, process_group: true)
      stdin.close
      wait_for_workers(directory)

      Process.kill("INT", -thread.pid)
      text, status = finish_run(output, thread)

      expect(text.scan("RSpec is shutting down and will print the summary report").size).to eq(1)
      expect(text).to match(/Finished in/)
      expect(status.exitstatus).to eq(1)
      expect(Dir.glob(File.join(directory, "shutdown-*")).size).to eq(2)
    ensure
      Process.kill("KILL", -thread.pid) if thread&.alive?
    end
  end

  it "force-quits and kills workers after a second SIGINT" do
    Dir.mktmpdir("multicore-interrupt") do |directory|
      stdin, output, thread = start_interrupt_run(directory, long_running: true)
      stdin.close
      wait_for_workers(directory)
      wait_for_active_groups(directory)
      pids = worker_pids(directory)

      Process.kill("INT", thread.pid)
      sleep 0.1
      Process.kill("INT", thread.pid)
      _text, status = finish_run(output, thread)

      expect(status.exitstatus).to eq(1)
      expect_workers_reaped(pids)
    ensure
      Process.kill("KILL", thread.pid) if thread&.alive?
      pids&.each do |pid|
        Process.kill("KILL", pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
