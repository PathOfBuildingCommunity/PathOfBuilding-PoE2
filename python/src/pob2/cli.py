"""Command-line access to the headless engine. Prints JSON, so it composes with jq / ConvertFrom-Json.

Examples:
  pob2 overview --build <code|link|file.xml>
  pob2 stats --build build.xml --keys TotalDPS Life
  pob2 call tree.search '{"query": "spell damage"}' --build <code>
  pob2 decode <code> > build.xml
  pob2 methods
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from pob2 import codec
from pob2.engine import EngineError
from pob2.service import PoBService


def _source(value: str) -> str:
    path = Path(value)
    if len(value) < 1024 and path.is_file():
        return path.read_text(encoding="utf-8")
    return value


def _emit(data: Any) -> None:
    json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


def _with_build(args: argparse.Namespace) -> PoBService:
    service = PoBService()
    if getattr(args, "build", None):
        service.load(_source(args.build))
    return service


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="pob2", description="Headless Path of Building 2")
    sub = parser.add_subparsers(dest="cmd", required=True)

    def with_build(p: argparse.ArgumentParser) -> argparse.ArgumentParser:
        p.add_argument("--build", "-b", help="Share code, pobb.in link, or path to a build XML file")
        return p

    with_build(sub.add_parser("overview", help="Build info, stats, skills, items"))
    stats = with_build(sub.add_parser("stats", help="Calculated stats"))
    stats.add_argument("--keys", nargs="*", help="Output keys, e.g. TotalDPS Life")
    call = with_build(sub.add_parser("call", help="Call any worker method"))
    call.add_argument("method", help="e.g. tree.search (see `pob2 methods`)")
    call.add_argument("params", nargs="?", default="{}", help="JSON object of parameters")
    sub.add_parser("methods", help="List worker methods")
    dec = sub.add_parser("decode", help="Share code / link -> XML")
    dec.add_argument("source")
    enc = sub.add_parser("encode", help="XML file -> share code")
    enc.add_argument("file")

    args = parser.parse_args(argv)
    try:
        if args.cmd == "decode":
            sys.stdout.write(codec.resolve(_source(args.source)) + "\n")
        elif args.cmd == "encode":
            sys.stdout.write(codec.encode_code(Path(args.file).read_text(encoding="utf-8")) + "\n")
        else:
            service = _with_build(args)
            try:
                if args.cmd == "overview":
                    _emit(service.overview())
                elif args.cmd == "stats":
                    _emit(service.call("stats.get", keys=args.keys))
                elif args.cmd == "call":
                    _emit(service.call(args.method, **json.loads(args.params)))
                elif args.cmd == "methods":
                    service.engine.start()
                    _emit(service.engine.methods)
            finally:
                service.engine.stop()
    except (EngineError, codec.CodecError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
