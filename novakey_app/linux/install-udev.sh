#!/usr/bin/env bash
set -euo pipefail

RULE_SOURCE="$(cd "$(dirname "$0")" && pwd)/70-novakey.rules"
RULE_TARGET="/etc/udev/rules.d/70-novakey.rules"

if [[ ! -f "$RULE_SOURCE" ]]; then
  echo "Missing rule: $RULE_SOURCE" >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

install -m 0644 "$RULE_SOURCE" "$RULE_TARGET"
udevadm control --reload-rules
udevadm trigger --subsystem-match=hidraw
echo "Installed $RULE_TARGET. Unplug and reconnect NovaKey before launching Studio."
