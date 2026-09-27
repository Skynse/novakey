#!/usr/bin/env python3
"""Ask a running NovaKey to enter the RP2040 USB bootloader."""

import glob
import os
import select
import sys
from pathlib import Path


def find_interface() -> str:
    denied = False
    for path in glob.glob("/sys/class/hidraw/hidraw*"):
        device = Path(path) / "device"
        try:
            info = (device / "uevent").read_text().upper()
            descriptor = (device / "report_descriptor").read_bytes()
            if "0000FEED:00004E4B" not in info:
                continue
            if b"\x06\x60\xff" not in descriptor or b"\x09\x4b" not in descriptor:
                continue
            node = "/dev/" + Path(path).name
            fd = os.open(node, os.O_RDWR | os.O_NONBLOCK)
            os.close(fd)
            return node
        except PermissionError:
            denied = True
        except OSError:
            continue
    if denied:
        raise RuntimeError("permission denied; install the NovaKey udev rule and reconnect")
    raise RuntimeError("NovaKey raw-HID interface not found")


def main() -> None:
    node = find_interface()
    fd = os.open(node, os.O_RDWR | os.O_NONBLOCK)
    try:
        packet = bytearray(32)
        packet[0:3] = b"NK\x30"
        packet[4:8] = b"BOOT"
        # hidraw writes include report ID zero for an unnumbered report.
        written = os.write(fd, b"\x00" + packet)
        if written != 33:
            raise RuntimeError("incomplete HID write")

        ready, _, _ = select.select([fd], [], [], 1.0)
        if ready:
            reply = os.read(fd, 32)
            if len(reply) == 32 and reply[0:3] == b"NK\x30" and reply[3] != 0:
                raise RuntimeError(f"firmware rejected boot command (status {reply[3]})")
    finally:
        os.close(fd)

    print("NovaKey is entering the RP2040 bootloader")


try:
    main()
except Exception as error:
    print(f"error: {error}", file=sys.stderr)
    raise SystemExit(1)
