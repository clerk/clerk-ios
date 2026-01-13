#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_dir="$root_dir/.codex/skills"
claude_dir="$root_dir/.claude/skills"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$codex_dir" "$claude_dir"

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

    mkdir -p "$codex_target" "$claude_target"
    rsync -a --delete --exclude ".git" "$skill_dir/" "$codex_target/"
    rsync -a --delete --exclude ".git" "$skill_dir/" "$claude_target/"
  done < <(find "$tmp_dir/$repo_name" -name SKILL.md -print0)

  if [[ $found -eq 0 ]]; then
    echo "No SKILL.md files found in $repo_url" >&2
    exit 1
  fi

}

sync_repo \
  "DimillianSkills" \
  "https://github.com/Dimillian/Skills"

sync_repo \
  "Swift-Concurrency-Agent-Skill" \
  "https://github.com/AvdLee/Swift-Concurrency-Agent-Skill"
