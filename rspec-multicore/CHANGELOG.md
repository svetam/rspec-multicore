# Changelog

## 0.2.0.pre3

- (#11) Fix Rails database lifecycle and parallel coverage for pre3

## 0.2.0.pre2

- Improves release validation and retry safety without changing runtime behavior.

## 0.2.0.pre1

- Uses one narrow `Runner#run_specs` patch and delegates suite ownership to RSpec.
- Adds a bounded plain-value Channel, persistent process Pool, parent object registry, and standard-event snapshot bridge.
- Adds `RSPEC_MULTICORE`, configurable workers, fork hooks, and reverse-order shutdown hooks.
- Supports Ruby 3.2+ and RSpec 3.13.x.
