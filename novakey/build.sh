#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
target_dir="$project_dir/target/thumbv6m-none-eabi/release"
out_dir="$project_dir/build"

cargo build --release --manifest-path "$project_dir/Cargo.toml"

elf="$target_dir/novakey"
bin="$out_dir/novakey.bin"
uf2="$out_dir/novakey.uf2"
mkdir -p "$out_dir"

objcopy_cmd="llvm-objcopy"
if command -v rust-objcopy >/dev/null 2>&1; then
    objcopy_cmd="rust-objcopy"
fi

"$objcopy_cmd" -O binary "$elf" "$bin"
python3 "$project_dir/tools/uf2.py" "$bin" "$uf2"
rm -f "$bin"

echo "Built $uf2"
