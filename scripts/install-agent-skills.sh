#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_dir="$root_dir/.codex/skills"
claude_dir="$root_dir/.claude/skills"
cursor_dir="$root_dir/.cursor/skills"
tmp_dir="$(mktemp -d)"
changed=0
rsync_flags=(-r --checksum --delete --exclude ".git" --omit-dir-times)

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$codex_dir" "$claude_dir" "$cursor_dir"

sync_repo() {
  local repo_name="$1"
  local repo_url="$2"

  git clone --quiet "$repo_url" "$tmp_dir/$repo_name"

  local found=0
  while IFS= read -r -d '' skill_file; do
    found=1
    local skill_dir
    skill_dir="$(dirname "$skill_file")"
    local skill_name
    skill_name="$(basename "$skill_dir")"
    local codex_target="$codex_dir/$skill_name"
    local claude_target="$claude_dir/$skill_name"
    local cursor_target="$cursor_dir/$skill_name"

    mkdir -p "$codex_target" "$claude_target" "$cursor_target"
    rsync_output=$(rsync "${rsync_flags[@]}" --itemize-changes "$skill_dir/" "$codex_target/")
    if [[ -n "${rsync_output}" ]]; then
      changed=1
    fi

    rsync_output=$(rsync "${rsync_flags[@]}" --itemize-changes "$skill_dir/" "$claude_target/")
    if [[ -n "${rsync_output}" ]]; then
      changed=1
    fi

    rsync_output=$(rsync "${rsync_flags[@]}" --itemize-changes "$skill_dir/" "$cursor_target/")
    if [[ -n "${rsync_output}" ]]; then
      changed=1
    fi
  done < <(find "$tmp_dir/$repo_name" -name SKILL.md -print0)

  if [[ $found -eq 0 ]]; then
    echo "No SKILL.md files found in $repo_url" >&2
    exit 1
  fi

}

sync_repo \
  "DimillianSkills" \
  "https://github.com/Dimillian/Skills"

echo "✅ Agent skills installed"
