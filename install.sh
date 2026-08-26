#!/usr/bin/env bash
# Install/upgrade the lgc1-wol*.py release artifacts.
# Run from the unpacked release archive (or repo root): ./install.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${HOME}/.local/bin/scripts"
LOCAL_BIN="${HOME}/.local/bin"
SYS_BIN="/usr/local/bin"

# Outcome of the selected resolver (set by the functions below).
DEST_DIR=""
INSTALL_MODE="copy"
SUDO_CMD=""

in_path() {
  case ":${PATH}:" in *":$1:"*) return 0 ;; esac
  return 1
}

# --- Resolvers: each picks a destination or returns 1 (no match) ---

# 1) Preferred: ~/.local/bin/scripts only if it already exists.
resolve_scripts() {
  [ -d "${SCRIPTS_DIR}" ] || return 1
  DEST_DIR="${SCRIPTS_DIR}"
}

# 2) Fallback: ~/.local/bin if it is already on PATH.
resolve_local() {
  in_path "${LOCAL_BIN}" || return 1
  mkdir -p "${LOCAL_BIN}"
  DEST_DIR="${LOCAL_BIN}"
  echo "note: ${SCRIPTS_DIR} absent; installing to ${LOCAL_BIN} instead." >&2
  echo "      bazzified-steam.sh looks for lgc1-wold.py under scripts/ — mkdir it or adjust the path." >&2
}

# 3) Fallback: /usr/local/bin, prompting copy vs symlink when interactive.
resolve_system() {
  [ -w "${SYS_BIN}" ] || SUDO_CMD="sudo"
  INSTALL_MODE="$(prompt_system_mode)"
  [ "${INSTALL_MODE}" != "quit" ] || exit 0
  DEST_DIR="${SYS_BIN}"
  echo "note: installing to ${SYS_BIN} (system-wide)." >&2
  echo "      bazzified-steam.sh looks for lgc1-wold.py under scripts/ — adjust its path." >&2
}

prompt_system_mode() {
  if [ ! -t 0 ]; then
    echo "copy" # non-interactive: default to copy
    return
  fi
  echo "Neither ${SCRIPTS_DIR} nor ${LOCAL_BIN} (on PATH) is available." >&2
  echo "Install to ${SYS_BIN} via:" >&2
  echo "  [c] copy    (${SUDO_CMD} cp -f)" >&2
  echo "  [s] symlink (${SUDO_CMD} ln -sfn, edits in repo take effect)" >&2
  echo "  [q] quit" >&2
  read -r -p "choice [c/s/q]: " choice
  case "$choice" in
  s | S) echo "symlink" ;;
  q | Q) echo "quit" ;;
  *) echo "copy" ;;
  esac
}

# --- Expose: link installed scripts into ~/.local/bin (usually on PATH) ---
# Used when the chosen destination is the scripts dir, which itself typically
# is not on PATH.
expose_in_local_bin() {
  mkdir -p "${LOCAL_BIN}"
  shopt -s nullglob
  local src
  for src in "${DEST_DIR}"/lgc1-wol*.py; do
    local base
    base="$(basename "$src")"
    ln -sfn "$src" "${LOCAL_BIN}/${base}"
    echo "linked: ${LOCAL_BIN}/${base} -> $src"
  done
  shopt -u nullglob
  if ! in_path "${LOCAL_BIN}"; then
    echo "warning: ${LOCAL_BIN} is not in your PATH" >&2
  fi
}

# --- Installer: one artifact at a time ---

install_one() {
  local src="$1" dest="$2" mode="$3" sudo="$4"
  local base
  base="$(basename "$src")"
  if [ "$mode" = "symlink" ]; then
    $sudo ln -sfn "$src" "${dest}/${base}"
  else
    $sudo install -m 0755 "$src" "${dest}/"
  fi
  echo "installed: ${dest}/${base}"
}

# --- Orchestration ---

main() {
  shopt -s nullglob
  local files=("${SRC_DIR}"/lgc1-wol*.py)
  shopt -u nullglob

  if [ "${#files[@]}" -eq 0 ]; then
    echo "error: no lgc1-wol*.py artifacts found in ${SRC_DIR}" >&2
    exit 1
  fi

  local resolver
  for resolver in resolve_scripts resolve_local resolve_system; do
    if "$resolver"; then
      break
    fi
  done

  if [ -z "${DEST_DIR}" ]; then
    echo "error: could not determine an install destination" >&2
    exit 1
  fi

  local f
  for f in "${files[@]}"; do
    install_one "$f" "${DEST_DIR}" "${INSTALL_MODE}" "${SUDO_CMD}"
  done

  if [ "${DEST_DIR}" = "${SCRIPTS_DIR}" ]; then
    expose_in_local_bin
  elif ! in_path "${DEST_DIR}"; then
    echo "warning: ${DEST_DIR} is not in your PATH" >&2
  fi
}

main "$@"
