#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/py-template-check.XXXXXX")
work_dir=$(cd -- "$work_dir" && pwd -P)
copier=(uvx --from 'copier==9.17.1' copier)

cleanup() {
    rm -rf -- "$work_dir"
}
trap cleanup EXIT

if [[ -n "${TEMPLATE_SOURCE:-}" ]]; then
    template_source=$TEMPLATE_SOURCE
    if [[ -d "$template_source" ]]; then
        template_source=$(cd -- "$template_source" && pwd -P)
    fi
else
    template_source="$work_dir/template-source"
    mkdir -p "$template_source"
    tar -C "$repo_root" --exclude=.git --exclude=./.playground -cf - . | tar -C "$template_source" -xf -
fi

copy_template() {
    local destination=$1
    shift

    local copier_args=(copy --defaults)
    if git -C "$template_source" rev-parse --git-dir >/dev/null 2>&1; then
        copier_args+=(-r HEAD)
    fi

    "${copier[@]}" "${copier_args[@]}" "$@" "$template_source" "$destination"
}

select_update_base_ref() {
    local source=$1

    if ! git -C "$source" rev-parse --git-dir >/dev/null 2>&1; then
        return 1
    fi

    # On release-tag CI, test updating from the prior tag into the tagged state.
    # In local dirty worktrees and normal branch CI, the latest tag is the base.
    if [[ -z $(git -C "$source" status --porcelain) ]] && \
        git -C "$source" describe --tags --exact-match HEAD >/dev/null 2>&1; then
        if git -C "$source" describe --tags --abbrev=0 HEAD^ 2>/dev/null; then
            return
        fi
        printf 'Current template is tagged, but no previous tag is available.\n' >&2
        printf 'Fetch full history and tags before running release-tag update checks.\n' >&2
        return 2
    fi

    git -C "$source" describe --tags --abbrev=0 2>/dev/null
}

check_project() {
    local project_dir=$1

    uv sync --directory "$project_dir"
    uv run --directory "$project_dir" pytest
    uv run --directory "$project_dir" ruff check .
    uv run --directory "$project_dir" ruff format --check .
    uv run --directory "$project_dir" pyright
    uv build --directory "$project_dir"
}

for python_version in 3.12 3.13 3.14; do
    version_suffix=${python_version//./}
    project_dir="$work_dir/python-$version_suffix"
    answers=(
        -d "project_name=sample-$version_suffix.with-dot"
        -d 'description=A "quoted" project'
        -d "python_version=$python_version"
    )
    # The 3.12 case exercises default package-name normalization for hyphens and periods.
    if [[ "$python_version" != 3.12 ]]; then
        answers+=(-d "package_name=acme_core_$version_suffix")
    fi

    copy_template "$project_dir" --quiet "${answers[@]}"
    check_project "$project_dir"
done

assert_rejected() {
    local case_name=$1
    local expected_message=$2
    local output_file="$work_dir/rejected-$case_name.log"
    shift 2

    if copy_template "$work_dir/rejected-$case_name" --quiet "$@" >"$output_file" 2>&1; then
        printf 'Expected Copier to reject %s\n' "$case_name" >&2
        return 1
    fi
    if ! grep -Fq "$expected_message" "$output_file"; then
        printf 'Copier rejected %s for an unexpected reason:\n' "$case_name" >&2
        sed -n '1,160p' "$output_file" >&2
        return 1
    fi
}

assert_rejected \
    invalid-project-name \
    'Must start and end with a letter or digit' \
    -d project_name=bad/name \
    -d package_name=acme_core \
    -d 'description=A sample project'
assert_rejected \
    keyword-package-name \
    'Must not be a Python keyword.' \
    -d project_name=sample-project \
    -d package_name=class \
    -d 'description=A sample project'
assert_rejected \
    multiline-description \
    'Must be a single line.' \
    -d project_name=sample-project \
    -d package_name=sample_project \
    -d $'description=First line\nSecond line'

assert_after_copy_message() {
    local destination="$work_dir/after copy message"
    local output_file="$work_dir/after-copy-message.log"
    local actual_destination
    local cd_command
    local expected
    local resolved_destination

    copy_template "$destination" \
        -d project_name=sample-message \
        -d 'description=A sample project' >"$output_file" 2>&1

    # Execute the template-controlled command to verify interpolation and shell quoting.
    cd_command=$(sed -n 's/^  \(cd .*\)$/\1/p' "$output_file")
    resolved_destination=$(cd -- "$destination" && pwd -P)
    if [[ -z "$cd_command" ]] || \
        ! actual_destination=$(eval "$cd_command" && pwd -P) || \
        [[ "$actual_destination" != "$resolved_destination" ]]; then
        printf 'After-copy cd command does not resolve to %s:\n' "$resolved_destination" >&2
        sed -n '1,160p' "$output_file" >&2
        return 1
    fi

    # Undefined message variables render empty, so assert the remaining content.
    for expected in sample-message 'git init' 'uv run pre-commit install'; do
        if ! grep -Fq "$expected" "$output_file"; then
            printf 'After-copy message is missing %s:\n' "$expected" >&2
            sed -n '1,160p' "$output_file" >&2
            return 1
        fi
    done
}

assert_after_copy_message

# Copying onto an existing project must preserve its documentation and agent instructions
# but still deliver the config.
assert_skip_if_exists() {
    local destination="$work_dir/existing-project"
    local sentinel='Existing content.'
    local expected
    local file

    mkdir -p "$destination"
    for file in README.md AGENTS.md CLAUDE.md pyproject.toml .gitignore \
        .pre-commit-config.yaml; do
        printf '%s\n' "$sentinel" >"$destination/$file"
    done

    copy_template "$destination" --quiet --overwrite \
        -d project_name=sample-existing \
        -d 'description=A sample project'

    for file in README.md AGENTS.md CLAUDE.md; do
        if ! grep -Fqx "$sentinel" "$destination/$file"; then
            printf 'Copy onto an existing project overwrote %s\n' "$file" >&2
            return 1
        fi
    done
    for file in pyproject.toml .gitignore .pre-commit-config.yaml; do
        if grep -Fqx "$sentinel" "$destination/$file"; then
            printf 'Copy onto an existing project skipped %s\n' "$file" >&2
            return 1
        fi
    done
    for expected in \
        'pyproject.toml:[tool.ruff]' \
        'pyproject.toml:[tool.ruff.lint]' \
        'pyproject.toml:[tool.pyright]' \
        'pyproject.toml:[tool.pytest.ini_options]' \
        '.gitignore:.venv' \
        '.pre-commit-config.yaml:ruff-check'; do
        if ! grep -Fq "${expected#*:}" "$destination/${expected%%:*}"; then
            printf 'Copy onto an existing project did not write %s to %s\n' \
                "${expected#*:}" "${expected%%:*}" >&2
            return 1
        fi
    done
}

assert_skip_if_exists

assert_update_from_previous_tag() {
    local update_base_ref
    local history_source=$repo_root
    local update_source="$work_dir/update-template-source"
    local destination="$work_dir/update-project"
    local sentinel='Project-authored content.'
    local expected
    local file
    local select_status

    if [[ -n "${TEMPLATE_SOURCE:-}" ]]; then
        if [[ ! -d "$template_source" ]] || \
            ! git -C "$template_source" rev-parse --git-dir >/dev/null 2>&1; then
            printf 'Skipping update test: TEMPLATE_SOURCE is not a local git repository.\n' >&2
            return
        fi
        history_source=$template_source
    fi

    if update_base_ref=$(select_update_base_ref "$history_source"); then
        :
    else
        select_status=$?
        if [[ $select_status -eq 2 ]]; then
            return 1
        fi
        printf 'Skipping update test: no template tag found in %s.\n' "$history_source" >&2
        return
    fi

    mkdir -p "$update_source"
    git -C "$history_source" archive "$update_base_ref" | tar -C "$update_source" -xf -
    git -C "$update_source" init -q
    git -C "$update_source" config user.email py-template-check@example.invalid
    git -C "$update_source" config user.name "py-template check"
    git -C "$update_source" add .
    git -C "$update_source" commit -q -m "Template $update_base_ref"
    git -C "$update_source" tag update-base

    git -C "$update_source" rm -r -q .
    tar -C "$template_source" --exclude=.git -cf - . | tar -C "$update_source" -xf -
    git -C "$update_source" add -A
    git -C "$update_source" commit --allow-empty -q -m "Current template"

    "${copier[@]}" copy --defaults --quiet -r update-base \
        -d project_name=sample-update \
        -d package_name=sample_update \
        -d 'description=A sample project' \
        "$update_source" "$destination"
    git -C "$destination" init -q
    git -C "$destination" config user.email py-template-check@example.invalid
    git -C "$destination" config user.name "py-template check"
    git -C "$destination" add .
    git -C "$destination" commit -q -m "Initial template copy"

    for file in README.md AGENTS.md CLAUDE.md; do
        printf '%s\n' "$sentinel" >"$destination/$file"
    done
    git -C "$destination" add README.md AGENTS.md CLAUDE.md
    git -C "$destination" commit -q -m "Customize project docs"

    "${copier[@]}" update --defaults --skip-answered --quiet -r HEAD "$destination"

    for file in README.md AGENTS.md CLAUDE.md; do
        if ! grep -Fqx "$sentinel" "$destination/$file"; then
            printf 'Copier update overwrote project-authored %s\n' "$file" >&2
            return 1
        fi
    done

    for expected in \
        '.pre-commit-config.yaml:uv run --locked ruff check --fix' \
        '.pre-commit-config.yaml:uv run --locked ruff format' \
        '.github/workflows/ci.yml:uv sync --locked' \
        '.github/workflows/ci.yml:uv run pyright'; do
        if ! grep -Fq "${expected#*:}" "$destination/${expected%%:*}"; then
            printf 'Copier update did not write %s to %s\n' \
                "${expected#*:}" "${expected%%:*}" >&2
            return 1
        fi
    done

    check_project "$destination"
}

assert_update_from_previous_tag

printf 'Template checks passed.\n'
