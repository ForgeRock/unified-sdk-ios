#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_PATH="${ROOT_DIR}/SampleApps/Ping.xcworkspace"
DOCS_DIR="${ROOT_DIR}/docs"

AUTHOR="Ping Identity"
AUTHOR_URL="https://www.pingidentity.com/"
GITHUB_URL="https://github.com/ForgeRock/ping-ios-sdk"
THEME="fullwidth"

MODULES=(
  Logger
  Storage
  Network
  Commons
  Browser
  Orchestrate
  DavinciPlugin
  JourneyPlugin
  Oidc
  Davinci
  TamperDetector
  DeviceId
  DeviceProfile
  Journey
  DeviceClient
  ExternalIdP
  ExternalIdPApple
  ExternalIdPGoogle
  ExternalIdPFacebook
  Protect
  ReCaptchaEnterprise
  Fido
  Oath
  Push
  Binding
  Recognize
)

get_scheme_override() {
  local module="$1"

  case "$module" in
    Network) echo "PingNetwork" ;;
    DeviceId) echo "PingDeviceId" ;;
    ExternalIdPFacebook) echo "PingExternalIdPFacebook" ;;
    Protect) echo "PingProtect" ;;
    *) echo "" ;;
  esac
}

get_project_schemes() {
  local project_path="$1"

  xcodebuild -list -project "${project_path}" 2>/dev/null | awk '
    /^ *Schemes:$/ { in_schemes=1; next }
    in_schemes {
      if ($0 ~ /^$/) exit
      if ($0 ~ /^[[:space:]]+/) {
        gsub(/^[[:space:]]+/, "", $0)
        print
      }
    }
  '
}

get_best_scheme() {
  local project_path="$1"
  local module="$2"
  local ping_module="Ping${module}"
  local schemes
  local scheme

  schemes="$(get_project_schemes "${project_path}")"

  # 1. Exact Ping<Module>
  while IFS= read -r scheme; do
    [[ -z "${scheme}" ]] && continue
    if [[ "${scheme}" == "${ping_module}" ]]; then
      echo "${scheme}"
      return 0
    fi
  done <<EOF
${schemes}
EOF

  # 2. Exact <Module>
  while IFS= read -r scheme; do
    [[ -z "${scheme}" ]] && continue
    if [[ "${scheme}" == "${module}" ]]; then
      echo "${scheme}"
      return 0
    fi
  done <<EOF
${schemes}
EOF

  # 3. Any non-test Ping* scheme
  while IFS= read -r scheme; do
    [[ -z "${scheme}" ]] && continue
    case "${scheme}" in
      *Tests|*UITests) continue ;;
    esac
    if [[ "${scheme}" == Ping* ]]; then
      echo "${scheme}"
      return 0
    fi
  done <<EOF
${schemes}
EOF

  # 4. Any non-test scheme
  while IFS= read -r scheme; do
    [[ -z "${scheme}" ]] && continue
    case "${scheme}" in
      *Tests|*UITests) continue ;;
    esac
    echo "${scheme}"
    return 0
  done <<EOF
${schemes}
EOF

  return 1
}

workspace_has_scheme() {
  local workspace_path="$1"
  local target_scheme="$2"

  xcodebuild -list -workspace "${workspace_path}" 2>/dev/null | awk '
    /^ *Schemes:$/ { in_schemes=1; next }
    in_schemes {
      if ($0 ~ /^$/) exit
      if ($0 ~ /^[[:space:]]+/) {
        gsub(/^[[:space:]]+/, "", $0)
        print
      }
    }
  ' | grep -Fxq "${target_scheme}"
}

echo "Cleaning consolidated docs directory..."
rm -rf "${DOCS_DIR}"
mkdir -p "${DOCS_DIR}"

if [[ ! -d "${WORKSPACE_PATH}" ]]; then
  echo "Workspace not found at ${WORKSPACE_PATH}"
  exit 1
fi

for module in "${MODULES[@]}"; do
  PROJECT_PATH="${ROOT_DIR}/${module}/${module}.xcodeproj"
  MODULE_DIR="${ROOT_DIR}/${module}"
  OUTPUT_PATH="${DOCS_DIR}/${module}"

  if [[ ! -d "${PROJECT_PATH}" ]]; then
    echo "Skipping ${module}: project not found at ${PROJECT_PATH}"
    continue
  fi

  scheme="$(get_scheme_override "${module}")"

  if [[ -z "${scheme}" ]]; then
    scheme="$(get_best_scheme "${PROJECT_PATH}" "${module}" || true)"
  fi

  if [[ -z "${scheme}" ]]; then
    echo "Skipping ${module}: no suitable scheme found in ${PROJECT_PATH}"
    continue
  fi

  if ! workspace_has_scheme "${WORKSPACE_PATH}" "${scheme}"; then
    echo "Skipping ${module}: scheme '${scheme}' is not shared in workspace ${WORKSPACE_PATH}"
    continue
  fi

  echo "Generating docs for ${module} using scheme ${scheme}..."

  pushd "${MODULE_DIR}" >/dev/null

  jazzy \
    --clean \
    --author "${AUTHOR}" \
    --author_url "${AUTHOR_URL}" \
    --github_url "${GITHUB_URL}" \
    --theme "${THEME}" \
    --disable-search \
    --hide-documentation-coverage \
    --output "${OUTPUT_PATH}" \
    --build-tool-arguments "-workspace,${WORKSPACE_PATH},-scheme,${scheme},-sdk,iphoneos,-destination,generic/platform=iOS"

  popd >/dev/null
done