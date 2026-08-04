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

`uvx` fetches copier, copier fetches this repo over HTTPS — no clone or install needed.

## Update a generated project

```sh
cd my-project
uvx copier update
```

Three-way merges template changes against your local edits; needs a clean worktree.
`.copier-answers.yml` records the version the project came from.

## Release a template change

```sh
git commit -am "..."
git tag -a v0.2.0 -m "..."
git push && git push origin v0.2.0
```

Tags must be annotated (`-a`) — `git push --follow-tags` skips lightweight tags, and
copier resolves to the latest tag on the remote.

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
- ruff runs in pre-commit; mypy does not — slow in hooks, fights the uv env. Run it
  on demand and in CI.
- Hooks are `local` and call `uv run ruff`, so ruff has one version: the dev dependency.
- Generic Python standards live in `~/.config/agents-config/AGENTS.md`. The generated
  `AGENTS.md` carries project-specific scope, commands, and invariants only.
