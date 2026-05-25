"""Conversion between Path of Building share codes and raw build XML.

A PoB build code is URL-safe base64 of zlib-deflated build XML. The headless engine
stubs out Deflate/Inflate, so we do the (de)compression here and hand the engine raw XML.

Mirrors src/Classes/ImportTab.lua:
    import: Inflate(base64.decode(code:gsub("-","+"):gsub("_","/")))
    export: base64.encode(Deflate(xml)):gsub("+","-"):gsub("/","_")
"""

from __future__ import annotations

import base64
import zlib


def code_to_xml(code: str) -> str:
    """Decode a PoB build code (URL-safe base64 + zlib) into build XML."""
    cleaned = "".join(code.split())  # strip whitespace/newlines
    std = cleaned.replace("-", "+").replace("_", "/")
    std += "=" * (-len(std) % 4)  # restore base64 padding
    raw = base64.b64decode(std)
    return zlib.decompress(raw).decode("utf-8")


def xml_to_code(xml: str) -> str:
    """Encode build XML into a PoB build code (URL-safe base64 + zlib)."""
    deflated = zlib.compress(xml.encode("utf-8"))
    b64 = base64.b64encode(deflated).decode("ascii")
    return b64.replace("+", "-").replace("/", "_")


def looks_like_xml(text: str) -> bool:
    return text.lstrip().startswith("<")


if __name__ == "__main__":
    sample = "<PathOfBuilding2><Build level=\"1\"/></PathOfBuilding2>"
    code = xml_to_code(sample)
    roundtrip = code_to_xml(code)
    assert roundtrip == sample, roundtrip
    print("buildcode roundtrip OK:", code)
