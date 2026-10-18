"""Path of Building share codes and build links."""

from __future__ import annotations

import base64
import re
import zlib

import httpx

# Paste sites that expose the raw share code at a predictable URL.
_RAW_URLS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"^https?://pobb\.in/(?:u/[^/]+/)?([\w-]+)/?$"), "https://pobb.in/{}/raw"),
    (re.compile(r"^https?://pastebin\.com/(?:raw/)?(\w+)/?$"), "https://pastebin.com/raw/{}"),
    (re.compile(r"^https?://poe\.ninja/poe2/pob/(\w+)/?$"), "https://poe.ninja/poe2/pob/raw/{}"),
]


class CodecError(ValueError):
    """Raised when a build code, link or XML cannot be decoded."""


def decode_code(code: str) -> str:
    """Share code (URL-safe base64 of zlib-deflated XML) -> build XML."""
    cleaned = re.sub(r"\s+", "", code).replace("-", "+").replace("_", "/")
    cleaned += "=" * (-len(cleaned) % 4)
    try:
        return zlib.decompress(base64.b64decode(cleaned)).decode("utf-8")
    except (ValueError, zlib.error) as exc:
        raise CodecError(f"Not a valid Path of Building code: {exc}") from exc


def encode_code(xml: str) -> str:
    """Build XML -> share code, matching PoB's own export format."""
    return base64.b64encode(zlib.compress(xml.encode("utf-8"), 9)).decode().replace("+", "-").replace("/", "_")


def raw_url(link: str) -> str | None:
    for pattern, template in _RAW_URLS:
        match = pattern.match(link.strip())
        if match:
            return template.format(match.group(1))
    return None


def resolve(source: str, *, timeout: float = 15.0) -> str:
    """Accept XML, a share code, or a supported paste link and return build XML."""
    text = source.strip()
    if text.startswith("<"):
        return text
    if text.startswith(("http://", "https://")):
        from pob2 import market  # noqa: PLC0415 - avoid importing httpx-heavy helpers for plain codes

        if market.is_character_url(text):
            try:
                return decode_code(market.character_code(text)[0])
            except ValueError as exc:
                raise CodecError(str(exc)) from exc
        url = raw_url(text)
        if not url:
            raise CodecError(
                "Unsupported link. Supported: pobb.in, pastebin.com, poe.ninja/poe2/pob, and poe.ninja character "
                "pages (poe2/builds/... or poe2/profile/...)."
            )
        resp = httpx.get(url, timeout=timeout, follow_redirects=True)
        resp.raise_for_status()
        text = resp.text.strip()
    return decode_code(text)
