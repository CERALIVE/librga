#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly ISSUE_LABEL="upstream-watch"
readonly ISSUE_TITLE="upstream-watch: librga inputs moved"
readonly ISLAND_HEADER="drivers/video/rockchip/rga3/include/rga.h"

for coordinate in JEFFYCN_SYNC_POINT AIROCKCHIP_API_VERSION ISLAND_REF; do
  if [[ -v "${coordinate}" ]]; then
    printf -v "caller_${coordinate}" '%s' "${!coordinate}"
  fi
done

# shellcheck source=../upstream-watch.env
source "${REPO_ROOT}/upstream-watch.env"

for coordinate in JEFFYCN_SYNC_POINT AIROCKCHIP_API_VERSION ISLAND_REF; do
  caller_coordinate="caller_${coordinate}"
  if [[ -v "${caller_coordinate}" ]]; then
    printf -v "${coordinate}" '%s' "${!caller_coordinate}"
  fi
done

: "${JEFFYCN_SYNC_POINT:?upstream-watch.env must define JEFFYCN_SYNC_POINT}"
: "${AIROCKCHIP_API_VERSION:?upstream-watch.env must define AIROCKCHIP_API_VERSION}"
: "${ISLAND_REF:?upstream-watch.env must define ISLAND_REF}"

moved=()
details=()

record_current() {
  details+=("- ${1}")
}

record_moved() {
  moved+=("$1")
  details+=("- **${1} moved:** ${2}")
}

is_commit_sha() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]]
}

read -r jeffycn_tip _ < <(git ls-remote https://github.com/JeffyCN/mirrors refs/heads/linux-rga-multi)
if [[ -z "${jeffycn_tip}" ]]; then
  printf '%s\n' 'Could not resolve JeffyCN linux-rga-multi.' >&2
  exit 1
fi
if [[ "${jeffycn_tip}" == "${JEFFYCN_SYNC_POINT}" ]]; then
  record_current "JeffyCN linux-rga-multi: ${jeffycn_tip} (current)"
else
  record_moved "JeffyCN linux-rga-multi" "recorded ${JEFFYCN_SYNC_POINT}; upstream ${jeffycn_tip}"
fi

changelog="$(curl --fail --silent --show-error https://raw.githubusercontent.com/airockchip/librga/main/CHANGELOG.md)"
airockchip_version=""
while IFS= read -r line; do
  if [[ "${line}" =~ ^##[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    airockchip_version="${BASH_REMATCH[1]}"
    break
  fi
done <<< "${changelog}"
if [[ -z "${airockchip_version}" ]]; then
  printf '%s\n' 'Could not parse the first airockchip CHANGELOG heading.' >&2
  exit 1
fi

expected_airockchip_version="${AIROCKCHIP_API_VERSION%%_*}"
if [[ "${airockchip_version}" == "${expected_airockchip_version}" ]]; then
  record_current "airockchip CHANGELOG: ${airockchip_version} matches ${AIROCKCHIP_API_VERSION}"
else
  record_moved "airockchip CHANGELOG" "recorded ${AIROCKCHIP_API_VERSION}; first heading ${airockchip_version}"
fi

core_error_file="$(mktemp)"
trap 'rm -f "${core_error_file}"' EXIT
if gh api repos/airockchip/librga/contents/core >/dev/null 2>"${core_error_file}"; then
  record_moved "airockchip core source" "core/ now exists; 1.10.6 source is published and the fixed-in-1.10.6-binary carries can be dropped"
elif [[ "$(<"${core_error_file}")" == *"HTTP 404"* ]]; then
  record_current "airockchip core source: absent (the binary carries remain required)"
else
  printf '%s\n' 'Could not determine whether airockchip/librga now publishes core/ source.' >&2
  exit 1
fi

island_latest="$(gh api repos/CERALIVE/rk3588-media-island/releases/latest --jq .tag_name)"
if [[ -z "${island_latest}" ]]; then
  printf '%s\n' 'Could not resolve the latest rk3588-media-island release.' >&2
  exit 1
fi

if is_commit_sha "${ISLAND_REF}"; then
  if gh api "repos/CERALIVE/rk3588-media-island/contents/${ISLAND_HEADER}?ref=${island_latest}" >/dev/null; then
    island_comparison="$(gh api "repos/CERALIVE/rk3588-media-island/compare/${ISLAND_REF}...${island_latest}" --jq .status)"
    case "${island_comparison}" in
      ahead)
        record_moved "rk3588-media-island" "recorded commit ${ISLAND_REF}; newer ${island_latest} publishes ${ISLAND_HEADER}, so the pin can move to a tag" ;;
      identical)
        record_current "rk3588-media-island: ${ISLAND_REF} is identical to latest ${island_latest}"
        ;;
      behind|diverged)
        record_current "rk3588-media-island: latest ${island_latest} is not newer than recorded commit ${ISLAND_REF}"
        ;;
      *)
        printf 'Unexpected island comparison status: %s\n' "${island_comparison}" >&2
        exit 1
        ;;
    esac
  else
    record_current "rk3588-media-island: latest ${island_latest} does not publish ${ISLAND_HEADER}"
  fi
elif [[ "${ISLAND_REF}" == "${island_latest}" ]]; then
  record_current "rk3588-media-island: ${ISLAND_REF} (current)"
else
  record_moved "rk3588-media-island" "recorded ${ISLAND_REF}; latest published release ${island_latest}"
fi

issue_body="$(mktemp)"
trap 'rm -f "${core_error_file}" "${issue_body}"' EXIT
{
  printf '# %s\n\n' "${ISSUE_TITLE}"
  if (( ${#moved[@]} == 0 )); then
    printf 'All watched librga inputs are current. This is the body that would accompany a clean DRY_RUN verdict.\n\n'
  else
    printf 'The issue-only watch found input changes. Review and update pins in a separate, human-reviewed change; do not use this issue as authorization to dispatch a build.\n\n'
  fi
  printf '## Watch results\n'
  printf '%s\n' "${details[@]}"
} > "${issue_body}"

if (( ${#moved[@]} == 0 )); then
  verdict='all current'
else
  verdict="moved inputs: ${moved[*]}"
fi
printf '%s\n' "${verdict}"
printf '%s\n' '--- would-be issue body ---'
while IFS= read -r body_line || [[ -n "${body_line}" ]]; do
  printf '%s\n' "${body_line}"
done < "${issue_body}"

if [[ "${DRY_RUN:-0}" == '1' ]]; then
  printf '%s\n' 'DRY_RUN=1: no GitHub issue mutation performed.'
  exit 0
fi

: "${GH_TOKEN:?GH_TOKEN is required when DRY_RUN is not 1}"
export GH_REPO="${GH_REPO:-CERALIVE/librga}"

gh label create "${ISSUE_LABEL}" \
  --description 'Scheduled watch: librga upstream input moved' \
  --color '0E8A16' >/dev/null 2>&1 || true
existing_issue="$(gh issue list --label "${ISSUE_LABEL}" --state open --limit 1 --json number --jq '.[0].number // empty')"

if (( ${#moved[@]} > 0 )); then
  if [[ -n "${existing_issue}" ]]; then
    gh issue edit "${existing_issue}" --title "${ISSUE_TITLE}" --body-file "${issue_body}"
    printf 'Updated existing issue #%s.\n' "${existing_issue}"
  else
    gh issue create --title "${ISSUE_TITLE}" --label "${ISSUE_LABEL}" --body-file "${issue_body}"
  fi
elif [[ -n "${existing_issue}" ]]; then
  gh issue close "${existing_issue}" --comment 'All watched librga inputs are current again — closed by the scheduled upstream watch.'
  printf 'Closed issue #%s.\n' "${existing_issue}"
else
  printf '%s\n' 'Nothing to close.'
fi
