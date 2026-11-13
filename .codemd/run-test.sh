#!/usr/bin/env bash
root="$(pwd)"
target="${1:-all}"
status=0
mkdir -p "$root/codemd-reports" "$root/.codemd/test-results"
if [ "$target" = "finalize" ]; then
  if [ ! -f "$root/.codemd/test-results/0.exit" ]; then echo "CODEMD_TIMEOUT 0"; echo "CODEMD_RESULT 0 124"; status=1; else code="$(cat "$root/.codemd/test-results/0.exit")"; [ "$code" -eq 0 ] || status=1; fi
  exit "$status"
fi
if [ "$target" = "all" ] || [ "$target" = "0" ]; then { echo '### CodeMD: changed-line coverage'; echo; echo 'Lines this change touched that the tests ran. The raw reports are in the **codemd-coverage-reports** zip under Artifacts, kept 90 days.'; echo; echo '| File | Changed lines run | Not run |'; echo '|---|---|---|'; } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"; fi
if [ "$target" = "all" ] || [ "$target" = "0" ]; then
( cd packages/cli && eval 'npx vitest run "src/__tests__" --coverage --coverage.reporter=json --coverage.include=src/constants.ts' ); code=$?
echo "$code" > "$root/.codemd/test-results/0.exit"
echo "CODEMD_RESULT 0 $code"; [ "$code" -eq 0 ] || status=1
( cd packages/cli && [ -f coverage/coverage-final.json ] && cp coverage/coverage-final.json "$root/codemd-reports/"0-istanbul-coverage-final.json ) || true
( cd packages/cli && eval 'npx --yes nyc report --temp-dir coverage --reporter=cobertura --report-dir .codemd-cobertura && cp .codemd-cobertura/cobertura-coverage.xml .codemd-cobertura.xml' >/dev/null 2>&1 && [ -s .codemd-cobertura.xml ] && cp .codemd-cobertura.xml "$root/codemd-reports/0-cobertura.xml" ) || true
( cd packages/cli && python3 "$root/.codemd/coverage_summary.py" istanbul coverage/coverage-final.json packages/cli/src/constants.ts 224 225 0 224,225 ) || true
if [ "$code" -ne 0 ] && [ "$code" -ne 124 ] && [ "$code" -ne 126 ] && [ "$code" -ne 127 ]; then passes=0; for n in 1 2; do ( cd packages/cli && timeout 300 bash -c 'npx vitest run "src/__tests__" --coverage --coverage.reporter=json --coverage.include=src/constants.ts' ) >/dev/null 2>&1 && passes=$((passes+1)); done; echo "CODEMD_RERUN 0 $passes 2"; fi
fi
exit "$status"
