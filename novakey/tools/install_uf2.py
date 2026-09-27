#!/usr/bin/env python3
"""Wait for RPI-RP2, mount it if necessary, then install a UF2."""

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def boot_volume():
    data = json.loads(
        subprocess.check_output(
            ["lsblk", "--json", "--paths", "--output", "NAME,LABEL,MOUNTPOINT"],
            text=True,
        )
    )

    def walk(devices):
        for device in devices:
            if device.get("label") == "RPI-RP2":
                return device
            found = walk(device.get("children", []))
            if found:
                return found
        return None

    return walk(data["blockdevices"])


def main() -> None:
    if len(sys.argv) != 2:
        raise RuntimeError("usage: install_uf2.py PATH_TO_UF2")
    uf2 = Path(sys.argv[1]).resolve()
    if not uf2.is_file():
        raise RuntimeError(f"UF2 not found: {uf2}")

    deadline = time.monotonic() + 20
    device = None
    while time.monotonic() < deadline:
        device = boot_volume()
        if device:
            break
        time.sleep(0.25)
    if not device:
        raise RuntimeError("timed out waiting for the RPI-RP2 drive")

    mountpoint = device.get("mountpoint")
    if not mountpoint:
        result = subprocess.run(
            ["udisksctl", "mount", "--block-device", device["name"]],
            check=True,
            capture_output=True,
            text=True,
        )
        # Query again instead of parsing localized udisksctl output.
        for _ in range(20):
            refreshed = boot_volume()
            mountpoint = refreshed.get("mountpoint") if refreshed else None
            if mountpoint:
                break
            time.sleep(0.1)
    if not mountpoint:
        raise RuntimeError("RPI-RP2 appeared but could not be mounted")

    target = Path(mountpoint) / uf2.name
    shutil.copyfile(uf2, target)
    print(f"Flashed {uf2.name}; NovaKey is rebooting")


try:
    main()
except Exception as error:
    print(f"error: {error}", file=sys.stderr)
    raise SystemExit(1)
