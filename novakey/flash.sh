#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -gt 1 ]]; then
    echo "usage: $0 [firmware.uf2]" >&2
    exit 2
fi

if [[ $# -eq 1 ]]; then
    uf2="$1"
else
    "$project_dir/build.sh"
    uf2="$project_dir/build/novakey.uf2"
fi

python3 "$project_dir/tools/reboot_bootloader.py"
python3 "$project_dir/tools/install_uf2.py" "$uf2"
