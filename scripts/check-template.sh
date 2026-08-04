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

    local copier_args=(copy --quiet --defaults)
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
    uv run --directory "$project_dir" mypy
    uv build --directory "$project_dir"
}

for python_version in 3.12 3.13 3.14; do
    version_suffix=${python_version//./}
    project_dir="$work_dir/python-$version_suffix"
    answers=(
        -d "project_name=sample-$version_suffix"
        -d 'description=A "quoted" project'
        -d "python_version=$python_version"
    )
    if [[ "$python_version" != 3.12 ]]; then
        answers+=(-d "package_name=acme_core_$version_suffix")
    fi

    copy_template "$project_dir" "${answers[@]}"
    check_project "$project_dir"
done

assert_rejected() {
    local case_name=$1
    local expected_message=$2
    local output_file="$work_dir/rejected-$case_name.log"
    shift 2

    if copy_template "$work_dir/rejected-$case_name" "$@" >"$output_file" 2>&1; then
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

printf 'Template checks passed.\n'
