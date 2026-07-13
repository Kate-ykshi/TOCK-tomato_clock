#!/usr/bin/env python3
import math
import os
import struct
import sys
import zlib


COLORS = {
    "background": (236, 244, 252, 255),
    "card": (250, 252, 255, 255),
    "blue": (105, 174, 241, 255),
    "deep_blue": (49, 107, 180, 255),
    "core": (67, 132, 216, 255),
}


ICON_FILES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

ICNS_FILES = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]


def blend(dst, src):
    sr, sg, sb, sa = src
    if sa == 255:
        return src
    dr, dg, db, da = dst
    alpha = sa / 255
    out_alpha = alpha + da / 255 * (1 - alpha)
    if out_alpha == 0:
        return (0, 0, 0, 0)
    return (
        int((sr * alpha + dr * da / 255 * (1 - alpha)) / out_alpha),
        int((sg * alpha + dg * da / 255 * (1 - alpha)) / out_alpha),
        int((sb * alpha + db * da / 255 * (1 - alpha)) / out_alpha),
        int(out_alpha * 255),
    )


def rounded_rect_alpha(x, y, left, top, right, bottom, radius):
    if x < left or x > right or y < top or y > bottom:
        return 0.0

    cx = min(max(x, left + radius), right - radius)
    cy = min(max(y, top + radius), bottom - radius)
    distance = math.hypot(x - cx, y - cy)
    edge = radius - distance
    return max(0.0, min(1.0, edge + 0.5))


def line_distance(px, py, ax, ay, bx, by):
    vx = bx - ax
    vy = by - ay
    wx = px - ax
    wy = py - ay
    length_sq = vx * vx + vy * vy
    if length_sq == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / length_sq))
    projection_x = ax + t * vx
    projection_y = ay + t * vy
    return math.hypot(px - projection_x, py - projection_y)


def circle_alpha(x, y, cx, cy, radius):
    edge = radius - math.hypot(x - cx, y - cy)
    return max(0.0, min(1.0, edge + 0.5))


def ring_alpha(x, y, cx, cy, radius, width):
    distance = math.hypot(x - cx, y - cy)
    edge = width / 2 - abs(distance - radius)
    return max(0.0, min(1.0, edge + 0.5))


def line_alpha(x, y, ax, ay, bx, by, width):
    edge = width / 2 - line_distance(x, y, ax, ay, bx, by)
    return max(0.0, min(1.0, edge + 0.5))


def apply_alpha(color, alpha):
    red, green, blue, base_alpha = color
    return (red, green, blue, int(base_alpha * alpha))


def render_icon(size):
    pixels = [bytearray(size * 4) for _ in range(size)]
    scale = size / 1024

    shapes = [
        ("rounded_rect", COLORS["background"], 0, 0, size, size, 224 * scale),
        ("rounded_rect", COLORS["card"], 124 * scale, 124 * scale, 900 * scale, 900 * scale, 198 * scale),
        ("circle", (*COLORS["blue"][:3], 58), 512 * scale, 512 * scale, 326 * scale),
        ("ring", COLORS["deep_blue"], 512 * scale, 512 * scale, 272 * scale, 50 * scale),
        ("line", COLORS["deep_blue"], 512 * scale, 282 * scale, 512 * scale, 512 * scale, 54 * scale),
        ("line", COLORS["deep_blue"], 512 * scale, 512 * scale, 682 * scale, 628 * scale, 54 * scale),
        ("line", COLORS["blue"], 512 * scale, 180 * scale, 512 * scale, 126 * scale, 46 * scale),
        ("line", COLORS["blue"], 512 * scale, 898 * scale, 512 * scale, 844 * scale, 46 * scale),
        ("line", COLORS["blue"], 898 * scale, 512 * scale, 844 * scale, 512 * scale, 46 * scale),
        ("line", COLORS["blue"], 180 * scale, 512 * scale, 126 * scale, 512 * scale, 46 * scale),
        ("circle", COLORS["core"], 512 * scale, 512 * scale, 40 * scale),
    ]

    for y in range(size):
        for x in range(size):
            color = (0, 0, 0, 0)
            sample_x = x + 0.5
            sample_y = y + 0.5

            for shape in shapes:
                kind = shape[0]
                shape_color = shape[1]

                if kind == "rounded_rect":
                    alpha = rounded_rect_alpha(sample_x, sample_y, *shape[2:])
                elif kind == "circle":
                    alpha = circle_alpha(sample_x, sample_y, *shape[2:])
                elif kind == "ring":
                    alpha = ring_alpha(sample_x, sample_y, *shape[2:])
                else:
                    alpha = line_alpha(sample_x, sample_y, *shape[2:])

                if alpha > 0:
                    color = blend(color, apply_alpha(shape_color, alpha))

            offset = x * 4
            pixels[y][offset:offset + 4] = bytes(color)

    return pixels


def png_chunk(chunk_type, data):
    return (
        struct.pack(">I", len(data))
        + chunk_type
        + data
        + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
    )


def write_png(path, width, height, pixels):
    raw = b"".join(b"\x00" + bytes(row) for row in pixels)
    payload = zlib.compress(raw, level=9)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)

    with open(path, "wb") as file:
        file.write(b"\x89PNG\r\n\x1a\n")
        file.write(png_chunk(b"IHDR", header))
        file.write(png_chunk(b"IDAT", payload))
        file.write(png_chunk(b"IEND", b""))


def write_icns(iconset_dir, output_path):
    chunks = []
    for icon_type, filename in ICNS_FILES:
        with open(os.path.join(iconset_dir, filename), "rb") as file:
            data = file.read()
        chunks.append(icon_type.encode("ascii") + struct.pack(">I", len(data) + 8) + data)

    payload = b"".join(chunks)
    with open(output_path, "wb") as file:
        file.write(b"icns" + struct.pack(">I", len(payload) + 8) + payload)


def main():
    if len(sys.argv) not in (2, 3):
        print("Usage: generate_icon.py OUTPUT.iconset [OUTPUT.icns]", file=sys.stderr)
        return 1

    output_dir = sys.argv[1]
    os.makedirs(output_dir, exist_ok=True)

    rendered_by_size = {}
    for filename, size in ICON_FILES:
        if size not in rendered_by_size:
            rendered_by_size[size] = render_icon(size)
        write_png(os.path.join(output_dir, filename), size, size, rendered_by_size[size])

    if len(sys.argv) == 3:
        write_icns(output_dir, sys.argv[2])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
