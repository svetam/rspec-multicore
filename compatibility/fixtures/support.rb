# frozen_string_literal: true

require "json"

module CompatibilityEvidence
  module_function

  def record(values)
    path = ENV.fetch("EVIDENCE_PATH")
    File.open(path, "a") do |file|
      file.flock(File::LOCK_EX)
      file.puts(JSON.generate(values))
      file.flush
    end
  end
end
