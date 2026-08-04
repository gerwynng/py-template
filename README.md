# py-template

Copier template for a Python project: uv, ruff, mypy strict, pytest, pre-commit,
and an `AGENTS.md` skeleton.

## Use

```sh
uvx copier copy gh:gerwynng/py-template my-project
cd my-project
uv sync
uv run pre-commit install
git init && git add -A && git commit -m "Initial commit from py-template"
```

No clone or install needed — `uvx` fetches copier, copier fetches this repo over HTTPS.

## Update an existing project

```sh
cd my-project
uvx copier update
```

Pulls template changes into a project generated from it, three-way merging against
your local edits. Requires the project to be a git repo with a clean working tree.
`.copier-answers.yml` in the generated project records which template version it came
from, so tag releases here when you change the template.

## What it generates

| file | purpose |
| --- | --- |
| `pyproject.toml` | project metadata plus `[tool.ruff]`, `[tool.mypy]`, `[tool.pytest.ini_options]` |
| `.pre-commit-config.yaml` | ruff check + format as local hooks |
| `AGENTS.md` | Scope / Commands / Invariants / Working notes skeleton |
| `CLAUDE.md` | `@AGENTS.md` |
| `src/<package>/`, `tests/` | src layout with a smoke test |

## Conventions

- Tool config lives in `pyproject.toml`, not separate `ruff.toml` / `setup.cfg` files.
- ruff runs in pre-commit; mypy does not — it is slow in hooks and fights the uv env.
  Run it on demand and in CI.
- Pre-commit hooks are `local` and call `uv run ruff`, so the ruff version is the one
  in dev dependencies rather than a second version pinned by a pre-commit rev.
- Generic Python standards are not repeated here; they live in the global
  `~/.config/agents-config/AGENTS.md`. The generated `AGENTS.md` is for
  project-specific scope, commands, and invariants only.
