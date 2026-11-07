---
profile: python
detect: [pyproject.toml, setup.py, requirements.txt]
parallel_implementers: free
build_serialization: none
build_lock: none
isolation: "one worktree per branch + one venv per worktree"
suite_cost: low
gate_script: scripts/gates/python.sh
ui_validation: none
failure: "any step exit != 0"
---

# Profile: python

Parameters for Python packages, services and CLIs. `/workflow-init` and the `orchestrate` skill read the frontmatter; the sections below are the rules that go with it.

## Gate (full, in this order)

`<r>` is `uv run` (uv.lock), `poetry run` (poetry.lock) or nothing (active `.venv`).

```sh
<r> ruff format --check .
<r> ruff check .
<r> mypy .
<r> pytest -n auto
```

`pytest -n auto` needs `pytest-xdist` in the dev dependencies. The gate is cheap: every implementer runs the full gate itself before reporting.

## Isolation

- Each worktree has its own `.venv` (`uv sync` or `python -m venv .venv && pip install -e .[dev]`); never share one.
- Tests that touch files use `tmp_path`; tests that bind ports use port 0.
- A service with a database: one test database per worktree, named in the TASK.

## UI validation

- Default `none`: the PR states it, and the orchestrator runs the CLI or API calls from the TASK's validation list and pastes the output as evidence.
- A web UI (Django, FastAPI + frontend): set `ui_validation: browser` and validate with headless Playwright like node-ts.

## CI

One job per supported Python version. Merge only with all jobs green.
