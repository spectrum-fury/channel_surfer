#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PIPX_BIN_DIR="${PIPX_BIN_DIR:-${HOME}/.local/bin}"
export PIPX_BIN_DIR

info() {
    printf '[channel-surfer] %s\n' "$*"
}

fail() {
    printf '[channel-surfer] Error: %s\n' "$*" >&2
    exit 1
}

command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "Python 3 was not found. Install Python 3 and run this script again."

if ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(sys.version_info < (3, 6))'; then
    fail "Python 3.6 or newer is required."
fi

pipx_cmd=()
if [[ -n "${CHANNEL_SURFER_PIPX:-}" ]]; then
    [[ -x "$CHANNEL_SURFER_PIPX" ]] || fail "CHANNEL_SURFER_PIPX is not executable: $CHANNEL_SURFER_PIPX"
    pipx_cmd=("$CHANNEL_SURFER_PIPX")
elif command -v pipx >/dev/null 2>&1; then
    pipx_cmd=("$(command -v pipx)")
elif "$PYTHON_BIN" -m pipx --version >/dev/null 2>&1; then
    pipx_cmd=("$PYTHON_BIN" -m pipx)
else
    pipx_venv="${HOME}/.local/share/channel-surfer/pipx"
    info "pipx was not found; installing it into $pipx_venv"
    "$PYTHON_BIN" -m venv "$pipx_venv" || fail "Could not create the pipx environment. Install the Python venv package and try again."
    "$pipx_venv/bin/python" -m pip install --disable-pip-version-check --upgrade pipx
    pipx_cmd=("$pipx_venv/bin/pipx")
fi

"${pipx_cmd[@]}" --version >/dev/null
mkdir -p "$PIPX_BIN_DIR"

info "Adding $PIPX_BIN_DIR to your shell PATH"
"${pipx_cmd[@]}" ensurepath --force

info "Installing Channel Surfer from $PROJECT_ROOT"
install_source="$(mktemp -d "${TMPDIR:-/tmp}/channel-surfer-install.XXXXXX")"
cleanup() {
    rm -rf "$install_source"
}
trap cleanup EXIT

cp -R "$PROJECT_ROOT/." "$install_source/"
rm -rf "$install_source/.git" "$install_source/build"
shopt -s nullglob
generated_metadata=("$install_source"/*.egg-info)
shopt -u nullglob
if ((${#generated_metadata[@]})); then
    rm -rf "${generated_metadata[@]}"
fi

"${pipx_cmd[@]}" install --force "$install_source"

launcher="$PIPX_BIN_DIR/channel-surfer"
[[ -x "$launcher" ]] || fail "pipx completed, but the launcher was not created at $launcher"

printf '\nChannel Surfer installed successfully.\n'
printf 'Launcher: %s\n' "$launcher"
if [[ ":${PATH}:" != *":${PIPX_BIN_DIR}:"* ]]; then
    printf 'Open a new terminal before running channel-surfer, or run:\n'
    printf '  export PATH="%s:%s"\n' "$PIPX_BIN_DIR" "\$PATH"
else
    printf 'Run: channel-surfer\n'
fi
