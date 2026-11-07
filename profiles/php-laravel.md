---
profile: php-laravel
detect: [composer.json, artisan]
parallel_implementers: "free (4+)"
build_serialization: none
build_lock: none
isolation: "one worktree per branch + one test database per worker"
suite_cost: low
gate_script: scripts/gates/php-laravel.sh
ui_validation: browser
failure: "any step exit != 0"
---

# Profile: php-laravel

Parameters for Laravel apps. `/workflow-init` and the `orchestrate` skill read the frontmatter; the sections below are the rules that go with it.

## Gate (full, in this order)

```sh
vendor/bin/pint --test
vendor/bin/phpstan analyse --no-progress --memory-limit=1G
vendor/bin/pest --parallel            # or: php artisan test --parallel
npm run build                         # only if package.json has a build script
```

The gate is cheap: every implementer runs the full gate itself before reporting.

## Isolation

- Each worktree has its own `.env` (copied from `.env.example`, untracked) with its own `APP_URL` port and its own test database, e.g. `DB_DATABASE=<app>_test_<topic>`.
- `--parallel` creates one database per process (`_test_1`, `_test_2`, ...): give the DB user rights to create them.
- Never point a worktree at the development or production database.
- Run `composer install` and `npm ci` inside each worktree; never share `vendor/` or `node_modules/`.

## UI validation: browser

- The orchestrator serves the worktree (`php artisan serve --port <port>`) and drives it with headless Playwright.
- Evidence: screenshots and the console/network log of each validation step, saved under the report.
- Seed data with factories or seeders into the worktree's own database.

## CI

One job per supported PHP version. Merge only with all jobs green.
