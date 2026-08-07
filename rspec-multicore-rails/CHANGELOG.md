# Changelog

## 0.2.0.pre2

- Uses Rails' standard database tasks to manage worker test databases and
  removes the prerelease custom task namespace.
- Supports multiple writable test configurations while leaving replicas and
  `database_tasks: false` configurations unmanaged.
- Improves release validation and retry safety.

## 0.2.0.pre1

- Uses the core worker count as the single concurrency source.
- Automatically handles only ActiveRecord database isolation.
- Adds focused prepare, drop, and recreate tasks and real SQLite isolation coverage.
- Supports Ruby 3.2+ and Rails/ActiveRecord/Railties 7.1–8.x.
