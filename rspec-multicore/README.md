# rspec-multicore

`rspec-multicore` runs RSpec 3.13 top-level example groups in persistent forked workers while the parent retains the real RSpec objects and reporter.

```ruby
require "rspec/multicore"

RSpec::Multicore.configure { _1.workers = 8 }
RSpec::Multicore.on_worker_fork { |slot| MyResource.connect(slot) }
RSpec::Multicore.on_worker_shutdown { |slot| MyResults.finish(slot) }
```

Use `RSPEC_MULTICORE=8` for an explicit count, or `RSPEC_MULTICORE=0`, `false`, or `off` for native serial RSpec. Unset, `auto`, `true`, or `on` selects the configured count or CPU count.

The gem patches only `RSpec::Core::Runner#run_specs`. It sends stable IDs and bounded result/exception snapshots between processes, supports only standard RSpec 3.13 reporter events, and replays events in seeded group order. Fail-fast and dry-run remain serial. Workers use `exit!`; inherited `at_exit` callbacks do not run.

Application resources and coverage tools are configured explicitly through the lifecycle hooks. Serial coverage is the safe default.

See the [project documentation](https://github.com/svetam/rspec-multicore) for details.
