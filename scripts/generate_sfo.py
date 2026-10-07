#!/usr/bin/env python3
"""
generate_sfo.py - Gera um arquivo param.sfo padrão Sony PlayStation 4/5
Compatível com OpenOrbis e Fake PKG Tools.
"""

import struct
import sys
from pathlib import Path

def create_sfo(output_path: Path, title_id: str, title: str, version: str = "01.00", content_id: str = None):
    if content_id is None:
        content_id = f"IV0000-{title_id}_00-0000000000000000"

    # Chaves obrigatórias em ordem alfabética estrita (requisito da especificação SFO)
    entries = [
        ("APP_TYPE", 0x0404, 0),                       # uint32: 0 (Normal App)
        ("APP_VER", 0x0204, version),                  # utf8 string
        ("ATTRIBUTE", 0x0404, 0),                      # uint32
        ("CATEGORY", 0x0204, "gd"),                    # utf8 string: Game Digital / Homebrew
        ("CONTENT_ID", 0x0204, content_id),            # utf8 string
        ("DOWNLOAD_DATA_SIZE", 0x0404, 0),             # uint32
        ("SYSTEM_VER", 0x0404, 0),                     # uint32
        ("TITLE", 0x0204, title),                      # utf8 string
        ("TITLE_ID", 0x0204, title_id),                # utf8 string
        ("VERSION", 0x0204, version)                   # utf8 string
    ]

    # Ordenar por chave ASCII
    entries.sort(key=lambda x: x[0])

    header_magic = b"\x00PSF"
    version_bytes = b"\x01\x01\x00\x00"  # Version 1.1

    num_entries = len(entries)
    entry_table_size = num_entries * 16
    key_table = bytearray()
    data_table = bytearray()

    entry_records = []

    for key, fmt, val in entries:
        key_offset = len(key_table)
        key_table.extend(key.encode("utf-8") + b"\x00")

        data_offset = len(data_table)
        if fmt == 0x0404: # uint32 integer
            val_bytes = struct.pack("<I", val)
            data_len = 4
            max_len = 4
            data_table.extend(val_bytes)
        elif fmt == 0x0204: # string
            str_bytes = val.encode("utf-8") + b"\x00"
            data_len = len(str_bytes)
            # Alinhar max_len para múltiplos de 4
            max_len = (data_len + 3) & ~3
            data_table.extend(str_bytes)
            if max_len > data_len:
                data_table.extend(b"\x00" * (max_len - data_len))

        entry_records.append({
            "key_offset": key_offset,
            "fmt": fmt,
            "data_len": data_len,
            "max_len": max_len,
            "data_offset": data_offset
        })

    # Alinhar tabelas
    key_table_offset = 20 + entry_table_size
    data_table_offset = key_table_offset + len(key_table)
    # Alinhamento de data table em 4 bytes
    pad_len = ((data_table_offset + 3) & ~3) - data_table_offset
    key_table.extend(b"\x00" * pad_len)
    data_table_offset += pad_len

    header = header_magic + version_bytes + struct.pack("<III", key_table_offset, data_table_offset, num_entries)

    entry_bytes = bytearray()
    for rec in entry_records:
        entry_bytes.extend(struct.pack("<HHIII", 
            rec["key_offset"],
            rec["fmt"],
            rec["data_len"],
            rec["max_len"],
            rec["data_offset"]
        ))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(header)
        f.write(entry_bytes)
        f.write(key_table)
        f.write(data_table)

    print(f"[SFO] Gerado com sucesso em: {output_path}")

if __name__ == "__main__":
    out = Path("sce_sys/param.sfo")
    if len(sys.argv) > 1:
        out = Path(sys.argv[1])
    create_sfo(out, title_id="RETR00001", title="Retro Player", version="01.00")

