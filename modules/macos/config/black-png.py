import struct
import sys
import zlib


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))


# One 8-bit RGB pixel at 0,0,0, behind PNG filter byte 0.
sys.stdout.buffer.write(
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00"))
    + chunk(b"IEND", b"")
)
