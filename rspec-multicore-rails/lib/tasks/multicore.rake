# frozen_string_literal: true

require "rspec/multicore/rails"

manager = -> { RSpec::Multicore::Rails::DatabaseManager.new }
test_in_scope = lambda do
  Rails.env.test? || (Rails.env.development? && !ENV["DATABASE_URL"] && !ENV["SKIP_TEST_DATABASE"])
end
allowed = lambda do |scope|
  scope == :all || (scope == :test ? Rails.env.test? : test_in_scope.call)
end

enhance = lambda do |task_name, operation, name: nil, scope: :current|
  next unless Rake::Task.task_defined?(task_name)

  Rake::Task[task_name].enhance do
    next unless allowed.call(scope)

    manager.call.public_send(operation, name:)
  end
end

enhance.call("db:create", :create_workers)
enhance.call("db:create:all", :create_workers, scope: :all)
enhance.call("db:prepare", :prepare_workers)
enhance.call("db:schema:load", :load_schema_workers)
enhance.call("db:test:purge", :purge_workers, scope: :all)
enhance.call("db:test:load_schema", :load_schema_workers, scope: :all)
enhance.call("db:purge", :purge_workers)
enhance.call("db:purge:all", :purge_workers, scope: :all)
enhance.call("db:drop", :drop_workers)
enhance.call("db:drop:all", :drop_workers, scope: :all)

Rake::Task.tasks.map(&:name).each do |task_name|
  case task_name
  when /\Adb:test:purge:(.+)\z/
    enhance.call(task_name, :purge_workers, name: Regexp.last_match(1), scope: :all)
  when /\Adb:test:load_schema:(.+)\z/
    enhance.call(task_name, :load_schema_workers, name: Regexp.last_match(1), scope: :all)
  when /\Adb:create:(?!all\z)(.+)\z/
    enhance.call(task_name, :create_workers, name: Regexp.last_match(1), scope: :test)
  when /\Adb:schema:load:(.+)\z/
    enhance.call(task_name, :load_schema_workers, name: Regexp.last_match(1), scope: :test)
  when /\Adb:drop:(?!all\z|_unsafe\z)(.+)\z/
    enhance.call(task_name, :drop_workers, name: Regexp.last_match(1), scope: :test)
  end
end
