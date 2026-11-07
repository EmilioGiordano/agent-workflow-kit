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

## Gate (stock steps; init derives the real ones from CI first)

`<r>` is `uv run --no-sync` (uv.lock), `poetry run` (poetry.lock) or nothing (the worktree's `.venv`).

```sh
<r> ruff format --check .
<r> ruff check .
<r> mypy .                    # if declared
<r> pytest -n auto            # -n auto only with pytest-xdist declared
```

- Keep only declared tools (e.g. black, flake8 or pyright instead of ruff and mypy, if that is what the project uses).
- `--no-sync` keeps `uv run` from installing. A missing tool fails its step.
- The gate is cheap: every implementer runs the full gate itself before reporting.

## Isolation

- Each worktree has its own `.venv` (`uv sync --frozen`, or `python -m venv .venv && pip install -e .[dev]`); never share one.
- Tests that touch files use `tmp_path`; tests that bind ports use port 0.
- A service with a database: one test database per worktree, named in the TASK.

## UI validation

- Default `none`: the PR states it. CLIs use `cli`; HTTP services use `http`.
- A web UI (Django, FastAPI + frontend): `browser`, with headless Playwright as in node-ts.
- Details: `reference/validation-modes.md`.

## CI

One job per supported Python version. Merge only with all jobs green.
