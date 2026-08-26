#!/usr/bin/env bash
# Install/upgrade the lgc1-wol*.py release artifacts into $HOME/.local/bin/scripts.
# Run from the unpacked release archive (or repo root): ./install.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${HOME}/.local/bin/scripts"

shopt -s nullglob
files=("${SRC_DIR}"/lgc1-wol*.py)
shopt -u nullglob

if [ "${#files[@]}" -eq 0 ]; then
    echo "error: no lgc1-wol*.py artifacts found in ${SRC_DIR}" >&2
    exit 1
fi

mkdir -p "${DEST_DIR}"

for f in "${files[@]}"; do
    install -m 0755 "$f" "${DEST_DIR}/"
    echo "installed: ${DEST_DIR}/$(basename "$f")"
done

case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) echo "warning: ${HOME}/.local/bin is not in your PATH" ;;
esac
