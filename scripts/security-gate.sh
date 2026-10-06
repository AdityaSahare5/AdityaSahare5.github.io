#!/usr/bin/env bash
# =====================================================================
# Security gate (stage 11)
# Reads all scanner reports, counts findings, applies the policy below,
# prints a summary table to the GitHub run page, and exits 1 on FAIL.
#
# POLICY (change these numbers to experiment):
MAX_SECRETS=0          # any leaked secret = fail
MAX_SAST_ERRORS=0      # Semgrep findings with severity ERROR
MAX_DEP_HIGH=0         # npm audit high + critical
MAX_IMAGE_CRITICAL=0   # Trivy CRITICAL CVEs in the container
MAX_IMAGE_HIGH=5       # Trivy HIGH CVEs in the container
MAX_DAST_HIGH=0        # ZAP alerts with risk = High
# =====================================================================
set -uo pipefail
DIR="${1:-reports}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

# A scanner that crashed must not look like "0 findings". Missing report = FAIL.
missing=0
for f in gitleaks.json semgrep.json npm-audit.json trivy-image.json zap.json; do
  if [ ! -s "$DIR/$f" ]; then echo "Missing report: $f"; missing=1; fi
done

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

count() { # count <file> <jq expression>  -> prints a number, or -1 if unreadable
  jq -r "$2" "$1" 2>/dev/null || echo -1
}

secrets=$(count "$DIR/gitleaks.json"     'length')
sast_err=$(count "$DIR/semgrep.json"     '[.results[]? | select(.extra.severity=="ERROR")] | length')
sast_warn=$(count "$DIR/semgrep.json"    '[.results[]? | select(.extra.severity=="WARNING")] | length')
dep_high=$(count "$DIR/npm-audit.json"   '(.metadata.vulnerabilities.high // 0) + (.metadata.vulnerabilities.critical // 0)')
dep_mod=$(count "$DIR/npm-audit.json"    '.metadata.vulnerabilities.moderate // 0')
img_crit=$(count "$DIR/trivy-image.json" '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')
img_high=$(count "$DIR/trivy-image.json" '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length')
img_med=$(count "$DIR/trivy-image.json"  '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length')
dast_high=$(count "$DIR/zap.json"        '[.site[]?.alerts[]? | select(.riskcode=="3")] | length')
dast_med=$(count "$DIR/zap.json"         '[.site[]?.alerts[]? | select(.riskcode=="2")] | length')

fail=0
row() { # row <check> <tool> <blocking count> <limit> <info>
  local status="PASS"
  if [ "$3" -lt 0 ]; then status="FAIL (unreadable report)"; fail=1
  elif [ "$3" -gt "$4" ]; then status="FAIL"; fail=1; fi
  echo "| $1 | $2 | $3 (limit $4) | $5 | $status |" >> "$SUMMARY"
}

{
  echo "## Security gate"
  echo ""
  echo "| Check | Tool | Blocking findings | Non-blocking | Result |"
  echo "|---|---|---|---|---|"
} >> "$SUMMARY"

row "Secrets"           "Gitleaks"  "$secrets"   "$MAX_SECRETS"        "-"
row "Source code"       "Semgrep"   "$sast_err"  "$MAX_SAST_ERRORS"    "$sast_warn warnings"
row "Dependencies"      "npm audit" "$dep_high"  "$MAX_DEP_HIGH"       "$dep_mod moderate"
row "Container (crit)"  "Trivy"     "$img_crit"  "$MAX_IMAGE_CRITICAL" "-"
row "Container (high)"  "Trivy"     "$img_high"  "$MAX_IMAGE_HIGH"     "$img_med medium"
row "Running app"       "OWASP ZAP" "$dast_high" "$MAX_DAST_HIGH"      "$dast_med medium alerts"

echo "" >> "$SUMMARY"
if [ "$missing" -eq 1 ]; then
  echo "**One or more scanner reports are missing, so the results can't be trusted.**" >> "$SUMMARY"
  fail=1
fi
if [ "$fail" -eq 1 ]; then
  echo "### Decision: FAIL. Production deploy is blocked." >> "$SUMMARY"
  echo "Download the **all-security-findings** artifact for details." >> "$SUMMARY"
  echo "Security gate FAILED"
  exit 1
fi
echo "### Decision: PASS. Promoting to production." >> "$SUMMARY"
echo "Security gate PASSED"
