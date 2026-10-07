#!/usr/bin/env python3
"""
generate_icons.py - Gera icon0.png (512x512) e pic1.png (1920x1080)
usando apenas a biblioteca padrão do Python (struct, zlib).
Totalmente compatível com orbis-pub-cmd e Fake PKG Tools.
"""

import struct
import zlib
from pathlib import Path

def write_png(file_path: Path, width: int, height: int, fill_r: int, fill_g: int, fill_b: int, accent_r: int, accent_g: int, accent_b: int):
    # PNG Header
    png_signature = b'\x89PNG\r\n\x1a\n'

    # IHDR Chunk
    # width (4), height (4), bit depth (1), color type 2 (Truecolor RGB), compression 0, filter 0, interlace 0
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    ihdr_crc = zlib.crc32(b"IHDR" + ihdr_data)
    ihdr_chunk = struct.pack(">I", len(ihdr_data)) + b"IHDR" + ihdr_data + struct.pack(">I", ihdr_crc)

    # Raw pixel scanlines
    raw_scanlines = bytearray()
    
    # Desenhar um gradiente / padrão elegante
    cx = width // 2
    cy = height // 2

    for y in range(height):
        raw_scanlines.append(0) # Filter type 0 (None)
        for x in range(width):
            # Desenha um retângulo ou moldura interna de destaque
            is_border = (x < 12 or x >= width - 12 or y < 12 or y >= height - 12)
            # Centro decorativo
            dx = abs(x - cx)
            dy = abs(y - cy)
            is_center_box = (dx < width // 4 and dy < height // 4)

            if is_border:
                raw_scanlines.extend((accent_r, accent_g, accent_b))
            elif is_center_box:
                # Gradiente suave no centro
                blend = min(255, int((1.0 - (dx + dy) / (width * 0.5)) * 180))
                r = min(255, fill_r + blend // 2)
                g = min(255, fill_g + blend // 2)
                b = min(255, fill_b + blend)
                raw_scanlines.extend((r, g, b))
            else:
                # Fundo suave
                shade = (y * 40) // height
                r = max(0, fill_r - shade)
                g = max(0, fill_g - shade)
                b = max(0, fill_b - shade)
                raw_scanlines.extend((r, g, b))

    # IDAT Chunk (comprimido)
    compressed_data = zlib.compress(bytes(raw_scanlines), level=6)
    idat_crc = zlib.crc32(b"IDAT" + compressed_data)
    idat_chunk = struct.pack(">I", len(compressed_data)) + b"IDAT" + compressed_data + struct.pack(">I", idat_crc)

    # IEND Chunk
    iend_crc = zlib.crc32(b"IEND")
    iend_chunk = struct.pack(">I", 0) + b"IEND" + struct.pack(">I", iend_crc)

    file_path.parent.mkdir(parents=True, exist_ok=True)
    with open(file_path, "wb") as f:
        f.write(png_signature)
        f.write(ihdr_chunk)
        f.write(idat_chunk)
        f.write(iend_chunk)

    print(f"[PNG] Gerado com sucesso: {file_path} ({width}x{height})")

if __name__ == "__main__":
    sce_sys = Path("sce_sys")
    # icon0.png: 512x512 (azul escuro / ciano neon retro)
    write_png(sce_sys / "icon0.png", 512, 512, 18, 30, 49, 0, 180, 216)
    # pic1.png: 1920x1080 (fundo de dashboard)
    write_png(sce_sys / "pic1.png", 1920, 1080, 12, 20, 35, 0, 150, 200)

