# Changelog

## 0.2.0.pre1

- Uses the core worker count as the single concurrency source.
- Automatically handles only ActiveRecord database isolation.
- Adds focused prepare, drop, and recreate tasks and real SQLite isolation coverage.
- Supports Ruby 3.2+ and Rails/ActiveRecord/Railties 7.1–8.x.
