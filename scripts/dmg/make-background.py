#!/usr/bin/env python3
"""Write a graphite DMG backdrop with a faint drag arrow. Stdlib only."""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

WIDTH = 660
HEIGHT = 400


def lerp(a: float, b: float, t: float) -> int:
    return int(a + (b - a) * t)


def in_arrow(x: int, y: int) -> bool:
    cx, cy = 330, 196
    # shaft
    if abs(y - cy) <= 7 and 248 <= x <= 392:
        return True
    # head
    dx = x - 400
    dy = abs(y - cy)
    return 0 <= dx <= 28 and dy <= 22 - dx * 0.7


def pixel(x: int, y: int) -> bytes:
    t = y / (HEIGHT - 1)
    r, g, b = lerp(32, 16, t), lerp(34, 18, t), lerp(40, 22, t)
    if in_arrow(x, y):
        r, g, b = lerp(r, 232, 0.42), lerp(g, 236, 0.42), lerp(b, 242, 0.42)
    return bytes((r, g, b))


def write_png(path: Path) -> None:
    raw = b"".join(b"\x00" + b"".join(pixel(x, y) for x in range(WIDTH)) for y in range(HEIGHT))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


if __name__ == "__main__":
    dest = Path(sys.argv[1] if len(sys.argv) > 1 else "background.png")
    write_png(dest)
