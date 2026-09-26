import pytest

from pob2 import codec

XML = '<?xml version="1.0"?><PathOfBuilding2><Build level="90"/></PathOfBuilding2>'


def test_round_trip():
    code = codec.encode_code(XML)
    assert "+" not in code and "/" not in code
    assert codec.decode_code(code) == XML


def test_decode_tolerates_whitespace_and_missing_padding():
    code = codec.encode_code(XML).rstrip("=")
    assert codec.decode_code(f"  {code[:10]}\n{code[10:]}  ") == XML


def test_resolve_passes_xml_through():
    assert codec.resolve(f"  {XML}\n") == XML


def test_invalid_code():
    with pytest.raises(codec.CodecError):
        codec.decode_code("not-a-build")


@pytest.mark.parametrize(
    ("link", "raw"),
    [
        ("https://pobb.in/abc123", "https://pobb.in/abc123/raw"),
        ("https://pobb.in/u/someone/abc123/", "https://pobb.in/abc123/raw"),
        ("https://pastebin.com/XyZ", "https://pastebin.com/raw/XyZ"),
        ("https://poe.ninja/poe2/pob/1a2b", "https://poe.ninja/poe2/pob/raw/1a2b"),
        ("https://example.com/x", None),
    ],
)
def test_raw_url(link, raw):
    assert codec.raw_url(link) == raw
