#!/usr/bin/env python3
"""Convert a flat RP2040 firmware binary into a UF2 image.

`elf2uf2`/`picotool` are not always available, so this packs a raw binary
(produced by `llvm-objcopy -O binary`, which lays out load addresses
contiguously) into the standard 256-byte UF2 blocks with the RP2040 family ID.
"""

import struct
import sys

FLASH_BASE = 0x10000000
RP2040_FAMILY_ID = 0xE48BFF56

MAGIC_START0 = 0x0A324655
MAGIC_START1 = 0x9E5D5157
MAGIC_END = 0x0AB16F30
FLAG_FAMILY_ID = 0x00002000
PAYLOAD_SIZE = 256


def pack(binary: bytes) -> bytes:
    payloads = [binary[i : i + PAYLOAD_SIZE] for i in range(0, len(binary), PAYLOAD_SIZE)]
    total = len(payloads)
    out = bytearray()
    for index, payload in enumerate(payloads):
        block = bytearray(512)
        data = payload + b"\x00" * (PAYLOAD_SIZE - len(payload))
        struct.pack_into(
            "<8I",
            block,
            0,
            MAGIC_START0,
            MAGIC_START1,
            FLAG_FAMILY_ID,
            FLASH_BASE + index * PAYLOAD_SIZE,
            PAYLOAD_SIZE,
            index,
            total,
            RP2040_FAMILY_ID,
        )
        block[32 : 32 + PAYLOAD_SIZE] = data
        struct.pack_into("<I", block, 508, MAGIC_END)
        out += block
    return bytes(out)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: uf2.py <firmware.bin> <firmware.uf2>", file=sys.stderr)
        return 2
    with open(sys.argv[1], "rb") as handle:
        binary = handle.read()
    with open(sys.argv[2], "wb") as handle:
        handle.write(pack(binary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
