#!/usr/bin/env bash
#
# Runs `trivy repo .` inside every spring-petclinic-* project, one at a time,
# and writes:
#   trivy-reports/<project>.txt   - full trivy table report
#   trivy-reports/<project>.json  - raw trivy JSON (git-ignored, used for the summary)
#   trivy-reports/SUMMARY.md      - CVE counts per severity, per project
#
# Requires: trivy, jq
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/trivy-reports"
mkdir -p "$OUT"

# Refresh the vulnerability DB once so every project is scanned against the same DB.
trivy repo --download-db-only --quiet "$ROOT/spring-petclinic-4.1.2" >/dev/null 2>&1 || true

summary="$OUT/SUMMARY.md"
{
  echo "| Project | Critical | High | Medium | Low | Total |"
  echo "|---|---:|---:|---:|---:|---:|"
} > "$summary"

PROJECTS=(
  spring-petclinic-2.7.3
  spring-petclinic-2.7.18
  spring-petclinic-2.7.35
  spring-petclinic-3.5.16
  spring-petclinic-3.5.17
  spring-petclinic-3.5.17-patched
  spring-petclinic-3.5.17-manually-patched
  spring-petclinic-4.0.9
  spring-petclinic-4.1.2
)

for name in "${PROJECTS[@]}"; do
  dir="$ROOT/$name"
  echo "==> Scanning $name"
  (
    cd "$dir"
    trivy repo . --quiet --skip-db-update --format json  --output "$OUT/$name.json"
    trivy repo . --quiet --skip-db-update --format table --output "$OUT/$name.txt"
  )
  jq -r --arg n "$name" '
    [.Results[]?.Vulnerabilities // [] | .[]] as $v
    | def c(s): $v | map(select(.Severity == s)) | length;
      "| \($n) | \(c("CRITICAL")) | \(c("HIGH")) | \(c("MEDIUM")) | \(c("LOW")) | \($v | length) |"
  ' "$OUT/$name.json" >> "$summary"
done

echo
cat "$summary"
