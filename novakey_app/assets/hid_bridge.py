#!/usr/bin/env python3
"""Line-delimited JSON bridge for NovaKey's Linux hidraw interface. No dependencies."""
import glob, json, os, select, sys
from pathlib import Path

def emit(value):
    print(json.dumps(value), flush=True)

def main():
    fd = None
    denied = False
    for path in glob.glob('/sys/class/hidraw/hidraw*'):
        device = Path(path) / 'device'
        try:
            info = (device / 'uevent').read_text().upper()
            descriptor = (device / 'report_descriptor').read_bytes()
            # Exact vendor/product plus the vendor-defined collection usage.
            if '0000FEED:00004E4B' not in info:
                continue
            if b'\x06\x60\xff' not in descriptor or b'\x09\x4b' not in descriptor:
                continue
            node = '/dev/' + Path(path).name
            fd = os.open(node, os.O_RDWR | os.O_NONBLOCK)
            break
        except PermissionError:
            denied = True
        except OSError:
            continue
    if fd is None:
        emit({'error': 'Permission denied: install the supplied NovaKey udev rule and reconnect.' if denied else 'NovaKey not found. Connect the pad and retry.'})
        return
    emit({'ready': True})
    pending = b''
    try:
        while True:
            ready, _, _ = select.select([fd, sys.stdin.fileno()], [], [], 1)
            if fd in ready:
                packet = os.read(fd, 32)
                if not packet:
                    break
                emit({'packet': list(packet)})
            if sys.stdin.fileno() in ready:
                chunk = os.read(sys.stdin.fileno(), 4096)
                if not chunk:
                    break
                pending += chunk
                while b'\n' in pending:
                    line, pending = pending.split(b'\n', 1)
                    packet = json.loads(line)['packet']
                    if len(packet) != 32 or packet[:2] != [78, 75]:
                        raise ValueError('Invalid NovaKey packet')
                    # Linux write includes a zero report ID for unnumbered reports.
                    if os.write(fd, bytes([0] + packet)) != 33:
                        raise OSError('Incomplete HID write')
    finally:
        os.close(fd)

try:
    main()
except Exception as error:
    emit({'error': str(error)})
