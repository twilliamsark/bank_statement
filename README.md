# Bank Statement

## Requirements

- Ruby 4.0.6
- Bundler
- SQLite3

## Setup

```sh
bin/setup
```

To develop this app against local clones of the companion gems instead of the pinned Git revisions in `Gemfile.lock`, point Bundler at the sibling checkouts:

```sh
bundle config set local.bank_account_statements ../bank_account_statements
bundle config set local.cc_year_end_statement ../cc_year_end_statement
```

CI troubleshooting:

- GitHub Actions checks out only this repository, so companion gems must stay resolvable from the Git sources recorded in `Gemfile` and `Gemfile.lock`.
- The `bundle config set local.* ...` commands above are local overrides for development only and should not be committed as path-based Gemfile entries.

## Run The App

```sh
bin/dev
```

## Tests

Run the full test suite:

```sh
bin/rails test
bin/rails test:system
```

## Linting

Run RuboCop locally with the project wrapper:

```sh
bin/rubocop
```

Useful targeted runs:

```sh
bin/rubocop app/models
bin/rubocop test/services
bin/rubocop -a
```

The wrapper uses the app's [.rubocop.yml](.rubocop.yml) configuration, which inherits from `rubocop-rails-omakase`.

## Gradual RuboCop Adoption

This repository is currently RuboCop-clean, so no `.rubocop_todo.yml` file is needed.

If you need to introduce RuboCop to a noisier branch or a legacy app without creating a large formatting-only diff, use this workflow:

1. Generate a temporary baseline with `bin/rubocop --auto-gen-config`.
2. Commit `.rubocop_todo.yml` separately so the baseline is explicit and reviewable.
3. Pick one directory or file at a time and run `bin/rubocop path/to/file_or_folder -a`.
4. Remove the resolved entries from `.rubocop_todo.yml` as each slice is cleaned up.
5. Keep behavior changes separate from style-only cleanup commits.
6. Delete `.rubocop_todo.yml` once the project runs clean without it.

Useful commands for low-churn cleanup:

```sh
bin/rubocop --auto-gen-config
bin/rubocop app/models/account.rb -a
bin/rubocop test/services -a
bin/rubocop --only Layout/LineLength app/models/account.rb
```

## CI

GitHub Actions runs the quality checks automatically on every pull request and on pushes to `main` through [.github/workflows/ci.yml](.github/workflows/ci.yml).

That workflow currently includes:

- `bin/rubocop -f github` in the `lint` job for Ruby style enforcement
- `bin/brakeman --no-pager` for Rails security scanning
- `bin/bundler-audit` for gem vulnerability checks
- `bin/importmap audit` for JavaScript dependency auditing
- `bin/rails db:test:prepare test` for the automated test suite
- `bin/rails db:test:prepare test:system` for system tests
