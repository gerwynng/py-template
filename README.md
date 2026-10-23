# py-template

Copier template for a Python project: uv, ruff, pyright strict, pytest, pre-commit,
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
`README.md`, `AGENTS.md`, and `CLAUDE.md` are in `_skip_if_exists`: once generated, they
belong to the project and never receive template changes.

## Adopt into an existing project

`copy` has no three-way merge - only `--overwrite` or `--skip`, whole files either way.
Render into a staging directory first so inspecting the template cannot overwrite existing
source, tests, or configuration:

```sh
cd existing-project
git status --short  # make sure all existing work is accounted for
staging_dir=$(mktemp -d)
uvx copier copy gh:gerwynng/py-template "$staging_dir"
```

Merge `[tool.ruff]`, `[tool.ruff.lint]`, `[tool.pyright]`, and `[tool.pytest.ini_options]`
from the staged `pyproject.toml`, plus the `ruff`, `pyright[nodejs]`, `pytest`, and
`pre-commit` development dependencies. Adjust Ruff's target version, Pyright's
`pythonVersion` and `include`, and pytest's `testpaths` to the existing project. Leave
`[project]`, its `dependencies`, `[build-system]`, and `[tool.uv.build-backend]`:
greenfield defaults that can erase real settings.

Merge `.gitignore` and `.pre-commit-config.yaml` instead of replacing them. Never copy the
generated `src/` or `tests/` skeleton over existing code. Copy anything else -
`.python-version`, `CLAUDE.md` - only after review.

Finally, copy `.copier-answers.yml` into the project and keep it under version control;
later `copier update` reads it. Reconcile first if the project already has one.

Expect `typeCheckingMode = "strict"` to be the expensive part on an existing codebase,
especially against untyped dependencies.

## What it generates

| file | purpose |
| --- | --- |
| `pyproject.toml` | metadata plus `[tool.ruff]`, `[tool.pyright]`, `[tool.pytest.ini_options]` |
| `.pre-commit-config.yaml` | ruff check + format, local hooks |
| `.github/workflows/ci.yml` | pytest, ruff, pyright, and build checks |
| `AGENTS.md` | Scope / Commands / Invariants / Working notes skeleton |
| `CLAUDE.md` | `@AGENTS.md` |
| `.python-version` | the chosen minimum Python version |
| `src/<package>/`, `tests/` | src layout with a smoke test |

## Conventions

- Tool config in `pyproject.toml`, not separate `ruff.toml` / `setup.cfg`.
- ruff runs in pre-commit; pyright does not - slow in hooks, fights the uv env. Run it
  on demand and in CI.
- Hooks are `local` and call `uv run --locked ruff`, so ruff has one version: the dev dependency.
- pyright is the same engine as Pylance. Both respect the generated `[tool.pyright]`
  table, so editor and CI diagnostics stay aligned.
- pyright is pinned as `pyright[nodejs]`. The extra resolves Node as a locked wheel, so
  `uv sync` stays sufficient - bare `pyright` downloads a runtime on first run.
- The generated `AGENTS.md` carries project-specific scope, commands, and invariants
  only; keep generic coding standards in a user-level agents file.

## Developing this template

Generate a sample from the working tree, including uncommitted changes, into the
gitignored `.playground/`:

```sh
uvx --from 'copier==9.17.1' copier copy --defaults -r HEAD \
  -d project_name=sample-project -d 'description=Local template playground' \
  . .playground/sample-project
```

Before releasing, run `scripts/check-template.sh`. It renders every supported Python
version, runs the generated checks and build, verifies that invalid answers are rejected,
and tests updating from the previous release tag. Then tag with an annotated tag
(`git tag -a vX.Y.Z`); Copier resolves the latest remote tag.
