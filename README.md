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

Merge `[tool.ruff]`, `[tool.ruff.lint]`, `[tool.pyright]`, and
`[tool.pytest.ini_options]` from the staged `pyproject.toml`. Adjust Ruff's target version,
Pyright's `pythonVersion` and `include`, and pytest's `testpaths` to the existing project.
Also merge the `ruff`, `pyright[nodejs]`, `pytest`, and `pre-commit` development
dependencies. Do not copy `[project]`, its `dependencies`, `[build-system]`, or
`[tool.uv.build-backend]`: those are greenfield defaults that can erase real settings.

Merge `.gitignore` and `.pre-commit-config.yaml` instead of replacing them. Copy any other
staged files only after reviewing them. Keep the existing `.python-version` unless the
selected template version should become the project's runtime pin, and preserve an existing
`CLAUDE.md` unless deliberately replacing it with the staged `@AGENTS.md` pointer. Do not
copy the generated `src/` or `tests/` skeleton over existing code.

Finally, copy `.copier-answers.yml` from the staging directory into the project and keep it
under version control. It records the template source and answers that make later
`copier update` work. If the project already has an answers file, do not replace it without
first reconciling which template owns it.

Expect `typeCheckingMode = "strict"` to be the expensive part on an existing codebase,
especially against untyped dependencies.

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
| `pyproject.toml` | metadata plus `[tool.ruff]`, `[tool.pyright]`, `[tool.pytest.ini_options]` |
| `.pre-commit-config.yaml` | ruff check + format, local hooks |
| `AGENTS.md` | Scope / Commands / Invariants / Working notes skeleton |
| `CLAUDE.md` | `@AGENTS.md` |
| `src/<package>/`, `tests/` | src layout with a smoke test |

## Conventions

- Tool config in `pyproject.toml`, not separate `ruff.toml` / `setup.cfg`.
- ruff runs in pre-commit; pyright does not - slow in hooks, fights the uv env. Run it
  on demand and in CI.
- Hooks are `local` and call `uv run ruff`, so ruff has one version: the dev dependency.
- pyright is the same engine as Pylance. Both respect the generated `[tool.pyright]`
  table, so editor and CI diagnostics stay aligned.
- pyright is pinned as `pyright[nodejs]`. The extra resolves Node as a locked wheel, so
  `uv sync` stays sufficient - bare `pyright` downloads a runtime on first run.
- Generic Python standards live in a user-level agents file, e.g.
  `~/.config/agents-config/AGENTS.md`. The generated `AGENTS.md` carries
  project-specific scope, commands, and invariants only.
