#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

run_count="${1:-${MAESTRO_BURN_IN_RUNS:-20}}"
if ! [[ "$run_count" =~ ^[1-9][0-9]*$ ]] || [ "$run_count" -gt 100 ]; then
  echo "❌ Run count must be an integer between 1 and 100."
  exit 1
fi

command -v gh >/dev/null 2>&1 || {
  echo "❌ GitHub CLI is required to download Maestro burn-in metrics."
  exit 1
}

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

list_args=(
  run list
  --workflow maestro-burn-in.yml
  --status completed
  --limit "$run_count"
  --json databaseId
  --jq '.[].databaseId'
)
if [ -n "${MAESTRO_BURN_IN_BRANCH:-}" ]; then
  list_args+=(--branch "$MAESTRO_BURN_IN_BRANCH")
fi

run_ids="$(gh "${list_args[@]}")"
if [ -z "$run_ids" ]; then
  echo "❌ No completed Maestro E2EHost Burn-in workflow runs were found."
  exit 1
fi

downloaded_runs=0
while IFS= read -r run_id; do
  [ -n "$run_id" ] || continue
  run_directory="$tmpdir/run-$run_id"
  mkdir -p "$run_directory"

  if gh run download "$run_id" \
    --pattern 'E2EHost-*-metrics' \
    --dir "$run_directory"; then
    downloaded_runs="$((downloaded_runs + 1))"
  else
    echo "⚠️  Run $run_id did not provide downloadable Maestro metrics." >&2
  fi
done <<< "$run_ids"

EXPECTED_METRICS="$((downloaded_runs * 8))" /usr/bin/ruby -rjson -e '
  def percentile(values, fraction)
    return nil if values.empty?

    sorted = values.sort
    sorted[(fraction * (sorted.length - 1)).round]
  end

  def duration(value)
    value.nil? ? "—" : "#{value}s"
  end

  files = Dir[File.join(ARGV.fetch(0), "**", "metrics.json")]
  metrics = files.map { |path| JSON.parse(File.read(path)) }
  expected = Integer(ENV.fetch("EXPECTED_METRICS"))
  abort("No burn-in metrics were downloaded.") if metrics.empty?

  puts "# Maestro E2EHost burn-in summary"
  puts
  puts "Collected #{metrics.count}/#{expected} expected harness metrics from #{expected / 8} workflow run(s)."
  puts
  puts "| Harness | Flow | Samples | Passed | Failed | Reliability | Median execution | P95 execution | Median total | P95 total |"
  puts "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"

  metrics.group_by { |entry| [entry.fetch("harness", "maestro"), entry.fetch("flow")] }.sort.each do |(harness, flow), entries|
    passed = entries.count { |entry| entry["outcome"] == "passed" }
    failed = entries.count - passed
    reliability = entries.empty? ? 0 : passed.fdiv(entries.count) * 100
    executions = entries.map { |entry| entry["execution_seconds"] || entry["flow_seconds"] }.compact
    totals = entries.map { |entry| entry["total_seconds"] }.compact

    columns = [
      harness,
      flow,
      entries.count,
      passed,
      failed,
      format("%.1f%%", reliability),
      duration(percentile(executions, 0.50)),
      duration(percentile(executions, 0.95)),
      duration(percentile(totals, 0.50)),
      duration(percentile(totals, 0.95)),
    ]
    puts "| #{columns.join(" | ")} |"
  end

  puts
  overall_passed = metrics.count { |entry| entry["outcome"] == "passed" }
  overall_reliability = metrics.empty? ? 0 : overall_passed.fdiv(metrics.count) * 100
  puts "Overall reliability: #{overall_passed}/#{metrics.count} (#{format("%.1f%%", overall_reliability)})."
  puts "Missing metrics: #{[expected - metrics.count, 0].max}."
' "$tmpdir"
