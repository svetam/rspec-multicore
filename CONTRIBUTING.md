# Contributing to RSpec::Multicore

Thank you for helping improve RSpec::Multicore. By participating, you agree to
follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting issues

Search existing issues before opening a report. Include:

- the smallest reproducible example;
- expected and actual behavior;
- Ruby, RSpec, Rails, and gem versions as applicable;
- operating system and architecture;
- serial output using `RSPEC_MULTICORE=0` and parallel output using an explicit
  worker count;
- the seed and formatter when ordering or reporter behavior matters.

Do not post credentials, proprietary application code, or private test data.
Report security-sensitive issues privately to `svetam.sd@pm.me`.

## Development setup

Fork the repository and create a branch from `master`. Install each gem's bundle
independently:

```bash
git clone https://github.com/YOUR-USERNAME/rspec-multicore.git
cd rspec-multicore/rspec-multicore
bundle install

cd ../rspec-multicore-rails
bundle install
```

## Verification

Run tests and lint for the gem you change. Run both when changing shared
behavior or release documentation.

```bash
cd rspec-multicore
bundle exec rake spec
bundle exec rubocop --cache false

cd ../rspec-multicore-rails
bundle exec rake spec
bundle exec rubocop --cache false
```

Add isolated tests for Channel, scheduling, snapshots, or database behavior.
Add integration coverage when behavior depends on real RSpec or Rails lifecycle
semantics. Keep fixed-seed serial/parallel parity checks for reporter changes.

## Design expectations

- Keep the RSpec patch limited to `RSpec::Core::Runner#run_specs`.
- Delegate suite ownership and exit calculation to native RSpec.
- Transfer stable IDs and bounded snapshots, not arbitrary object graphs.
- Keep Channel and process scheduling testable without RSpec.
- Keep automatic Rails integration limited to ActiveRecord.
- Use lifecycle hooks for application-specific resources.
- Preserve serial fallback for fail-fast, dry-run, and unsupported runtimes.
- Avoid new dependencies and abstractions unless current behavior requires them.

See [DEVELOPMENT.md](DEVELOPMENT.md) for the current architecture.

## Pull requests

- Keep changes focused and preserve backward compatibility unless the change is
  explicitly documented as breaking.
- Add or update tests and documentation.
- Update the relevant changelog for user-visible changes.
- Run `git diff --check`, both applicable suites, and RuboCop.
- Do not include generated gems, coverage output, lock changes from unrelated
  dependency experiments, or application-specific integrations.
- Use a concise commit subject and explain important compatibility or design
  decisions in the body.

Maintainers may ask contributors to squash fixup commits before merge.
