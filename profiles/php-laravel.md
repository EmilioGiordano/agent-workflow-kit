---
profile: php-laravel
detect: [composer.json, artisan]
parallel_implementers: "free (4+), bounded by database connections"
build_serialization: none
build_lock: none
isolation: "one worktree per branch + one test database per worktree (.env.testing)"
suite_cost: low
gate_script: scripts/gates/php-laravel.sh
ui_validation: browser
failure: "any step exit != 0"
---

# Profile: php-laravel

Parameters for Laravel apps. `/workflow-init` and the `orchestrate` skill read the frontmatter; the sections below are the rules that go with it.

## Gate (stock steps; init derives the real ones from CI first)

```sh
test-db-guard                          # always first; refuses unless the testing DB is a test one
vendor/bin/pint --test                 # if pint is declared
vendor/bin/phpstan analyse --no-progress --memory-limit=1G   # if phpstan/larastan is declared
php artisan test [--parallel]          # or vendor/bin/pest; --parallel only with paratest installed
npm run build                          # only if package.json has scripts.build
```

- Keep only the tools composer.json declares; record the rest as `# dropped: <tool> (not declared)`.
- The guard reads `DB_DATABASE` from phpunit.xml `<env>` (commented lines do not count), then from `.env.testing`. It passes for `:memory:` or a name containing `test`. Otherwise the test step does not run. Never remove the guard.
- The gate is cheap: every implementer runs the full gate itself before reporting.

## Isolation

- Never point tests at the development or production database. `RefreshDatabase` and `LazilyRefreshDatabase` wipe the database they connect to.
- Each worktree gets its own `.env.testing` (untracked, gitignored), separate from `.env`: copied from `.env.example`, `APP_ENV=testing`, `DB_DATABASE=<app>_test_<topic>`. phpunit.xml may pin the DB instead (e.g. sqlite `:memory:`).
- Serving for validation uses the worktree's own `.env` with its own `APP_URL` port and database.
- `--parallel` creates one database per process (`<db>_test_1`, `_test_2`, ...). The DB user needs the right to create them. Count the connections: worktrees × processes must stay under the server's `max_connections` (Postgres default 100).
- Run `composer install` (and `npm ci` if there are assets) inside each worktree; never share `vendor/` or `node_modules/`.

## UI validation

- Views or a frontend: `browser`. Serve the worktree with `php artisan serve --port <port>` and drive it with headless Playwright.
- An API with no views: `http`. Use the same serve command, then curl or newman checks; the evidence is the request/response log.
- Details: `reference/validation-modes.md`. Seed with factories or seeders into the worktree's own database.

## CI

One job per supported PHP version. No CI (`ci: none`): the orchestrator re-runs the gate on the merged result in its place.
