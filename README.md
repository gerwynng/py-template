# py-template

Copier template for a Python project: uv, ruff, mypy strict, pytest, pre-commit,
and an `AGENTS.md` skeleton.

## Use

```sh
uvx copier copy gh:gerwynng/py-template my-project
cd my-project
git init  # pre-commit install writes to .git/hooks
uv sync
uv run pre-commit install
git add -A && git commit -m "Initial commit from py-template"
```

## Update a generated project

```sh
cd my-project
uvx copier update
```

Three-way merges template changes into a clean worktree using `.copier-answers.yml`.

## Release a template change

```sh
scripts/check-template.sh
git add -A && git commit -m "..."
git tag -a vX.Y.Z -m "..."
git push && git push origin vX.Y.Z
```

Use annotated tags; Copier resolves the latest remote tag.

The template check renders every supported Python version, exercises custom package
names and quoted descriptions, runs the generated checks and build, and verifies that
invalid answers are rejected.

## What it generates

| file | purpose |
| --- | --- |
| `pyproject.toml` | metadata plus `[tool.ruff]`, `[tool.mypy]`, `[tool.pytest.ini_options]` |
| `.pre-commit-config.yaml` | ruff check + format, local hooks |
| `AGENTS.md` | Scope / Commands / Invariants / Working notes skeleton |
| `CLAUDE.md` | `@AGENTS.md` |
| `src/<package>/`, `tests/` | src layout with a smoke test |

## Conventions

- Tool config in `pyproject.toml`, not separate `ruff.toml` / `setup.cfg`.
- ruff runs in pre-commit; mypy does not - slow in hooks, fights the uv env. Run it
  on demand and in CI.
- Hooks are `local` and call `uv run ruff`, so ruff has one version: the dev dependency.
- The generated `AGENTS.md` carries project-specific scope, commands, and invariants
  only. This template assumes generic Python standards live in a user-level agents
  file, e.g. `~/.config/agents-config/AGENTS.md`.
