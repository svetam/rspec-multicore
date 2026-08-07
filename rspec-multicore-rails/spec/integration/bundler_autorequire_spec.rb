# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

RSpec.describe "Bundler autorequire" do
  it "loads the Rails adapter without an explicit require" do
    Dir.mktmpdir("rspec-multicore-bundler") do |directory|
      root = File.expand_path("../../..", __dir__)
      gemfile = File.join(directory, "Gemfile")
      File.write(
        gemfile,
        <<~RUBY
          source "https://rubygems.org"
          gem "rspec-multicore", path: #{File.join(root, "rspec-multicore").inspect}
          gem "rspec-multicore-rails", path: #{File.join(root, "rspec-multicore-rails").inspect}
        RUBY
      )

      command = <<~RUBY
        require "bundler"
        Bundler.setup(:default)
        Bundler.require(:default)
        abort "Rails adapter was not loaded" unless defined?(RSpec::Multicore::Rails::Railtie)
      RUBY
      output, status = Open3.capture2e(
        { "BUNDLE_GEMFILE" => gemfile },
        Gem.ruby,
        "-e",
        command,
        chdir: directory
      )

      expect(status).to be_success, output
    end
  end
end
