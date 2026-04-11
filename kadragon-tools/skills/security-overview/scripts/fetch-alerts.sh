#!/usr/bin/env bash
# fetch-alerts.sh — Collect all GitHub security alerts for the authenticated user's repos.
#
# Usage:
#   bash fetch-alerts.sh [output_dir]
#
# Output:
#   ${OUTPUT_DIR}/dependabot.json   — Dependabot vulnerability alerts (GraphQL)
#   ${OUTPUT_DIR}/code-scanning/    — Per-repo code scanning alerts (REST)
#   ${OUTPUT_DIR}/secret-scanning/  — Per-repo secret scanning alerts (REST, secrets redacted)
#   ${OUTPUT_DIR}/repos.txt         — List of all owned repos (name url)
#
# Requirements: gh CLI authenticated (gh auth status)
# Exit codes: 1 = gh not authenticated

set -euo pipefail

OUTPUT_DIR="${1:-.security-scan}"
mkdir -p "${OUTPUT_DIR}/code-scanning" "${OUTPUT_DIR}/secret-scanning"

# --- Pre-flight: auth check ---
if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

GH_USER=$(gh api user --jq '.login')
echo "Authenticated as: ${GH_USER}"

# --- Step 1: List all owned repos ---
echo "Listing repos..."
gh repo list "${GH_USER}" --json name,url --limit 300 -q '.[] | "\(.name) \(.url)"' \
  > "${OUTPUT_DIR}/repos.txt"

REPO_COUNT=$(wc -l < "${OUTPUT_DIR}/repos.txt" | tr -d ' ')
echo "Found ${REPO_COUNT} repos."

# --- Step 2: Dependabot alerts via GraphQL (paginated) ---
echo "Fetching Dependabot alerts via GraphQL..."
gh api graphql --paginate -f query='
{
  viewer {
    repositories(first: 100, ownerAffiliations: OWNER) {
      nodes {
        name
        url
        vulnerabilityAlerts(first: 100, states: OPEN) {
          totalCount
          nodes {
            securityVulnerability {
              package { name ecosystem }
              severity
              advisory { summary ghsaId }
              firstPatchedVersion { identifier }
            }
          }
        }
      }
    }
  }
}' > "${OUTPUT_DIR}/dependabot.json" 2>/dev/null || {
  echo "WARNING: GraphQL query failed (may lack permissions). Continuing..." >&2
}

# --- Step 3: Code Scanning + Secret Scanning via REST ---
echo "Fetching Code Scanning and Secret Scanning alerts..."

while read -r REPO _URL; do
  # Code Scanning (403 = not enabled, skip gracefully)
  HTTP_CODE=$(gh api "repos/${GH_USER}/${REPO}/code-scanning/alerts?state=open&per_page=100" \
    2>/dev/null) && echo "${HTTP_CODE}" > "${OUTPUT_DIR}/code-scanning/${REPO}.json" \
    || echo "[]" > "${OUTPUT_DIR}/code-scanning/${REPO}.json"

  # Secret Scanning (404 = disabled, skip gracefully; strip secret values)
  HTTP_CODE=$(gh api "repos/${GH_USER}/${REPO}/secret-scanning/alerts?state=open&per_page=100" \
    --jq '[.[] | del(.secret)]' 2>/dev/null) && echo "${HTTP_CODE}" > "${OUTPUT_DIR}/secret-scanning/${REPO}.json" \
    || echo "[]" > "${OUTPUT_DIR}/secret-scanning/${REPO}.json"
done < "${OUTPUT_DIR}/repos.txt"

echo "Done. Results in ${OUTPUT_DIR}/"
