#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/py-template-check.XXXXXX")
copier=(uvx --from 'copier==9.17.1' copier)

cleanup() {
    rm -rf -- "$work_dir"
}
trap cleanup EXIT

if [[ -n "${TEMPLATE_SOURCE:-}" ]]; then
    template_source=$TEMPLATE_SOURCE
else
    template_source="$work_dir/template-source"
    mkdir -p "$template_source"
    tar -C "$repo_root" --exclude=.git -cf - . | tar -C "$template_source" -xf -
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

printf 'Template checks passed.\n'
