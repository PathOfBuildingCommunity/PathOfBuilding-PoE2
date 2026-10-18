"""poe.ninja / trade helpers that don't need the network."""

import json
from urllib.parse import parse_qs, urlparse

import pytest

from pob2 import codec, market


def test_trade_url_round_trips_query():
    query = market.unique_query("Kaom's Heart", "Conqueror Plate")
    url = market.trade_url("Forbidden Rites", query)
    parsed = urlparse(url)
    assert parsed.path == "/trade2/search/poe2/Forbidden%20Rites"
    assert json.loads(parse_qs(parsed.query)["q"][0]) == query


@pytest.mark.parametrize(
    ("divine", "expected"),
    [(3.25, "3.2 div"), (150, "150 div"), (0.5, "353 ex")],
)
def test_format_price(divine, expected):
    assert market.format_price(divine, {"exalted": 706.5}) == expected


def test_character_url_detection():
    assert market.is_character_url("https://poe.ninja/poe2/builds/forbiddenrites/character/acc-1234/MyChar?i=0")
    assert not market.is_character_url("https://poe.ninja/poe2/pob/1a2b")


def test_character_url_resolution(monkeypatch):
    snapshot = {"url": "forbiddenrites", "name": "Forbidden Rites", "version": "v1", "snapshotName": "fr"}
    index = {"snapshotVersions": [snapshot]}
    xml = "<PathOfBuilding2/>"
    calls = []

    def fake_get(url, ttl, params=None, timeout=20.0):
        calls.append((url, params))
        if url.endswith("index-state"):
            return index
        return {"pathOfBuildingExport": codec.encode_code(xml)}

    monkeypatch.setattr(market, "_get_json", fake_get)
    assert codec.resolve("https://poe.ninja/poe2/builds/forbiddenrites/character/acc-1234/My%20Char") == xml
    assert calls[-1][0].endswith("/poe2/api/builds/v1/character")
    assert calls[-1][1]["name"] == "My Char" and calls[-1][1]["overview"] == "fr"


def test_profile_url_resolution(monkeypatch):
    xml = "<PathOfBuilding2/>"
    calls = []

    def fake_get(url, ttl, params=None, timeout=20.0):
        calls.append(url)
        if url.endswith("index-state"):
            return {"economyLeagues": [{"url": "forbiddenrites", "name": "Forbidden Rites"}]}
        return {"type": "found", "charModel": {"pathOfBuildingExport": codec.encode_code(xml)}}

    monkeypatch.setattr(market, "_get_json", fake_get)
    link = "https://poe.ninja/poe2/profile/Exile-1234/forbiddenrites/character/SomeChar"
    assert market.parse_character_url(link) == ("profile", "forbiddenrites", "Exile-1234", "SomeChar")
    assert codec.resolve(link) == xml
    assert "/poe2/api/profile/characters/Exile-1234/forbiddenrites/SomeChar/model/" in calls[0]
    assert market.character_league(link) == "Forbidden Rites"
