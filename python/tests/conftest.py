import shutil
import subprocess

import pytest

from pob2.engine import Engine, find_repo_root
from pob2.service import PoBService


def _luajit_supports_pob() -> bool:
    exe = shutil.which("luajit")
    if not exe:
        return False
    # PoB uses LuaJIT's 2026 syntax extensions (compound assignment, continue).
    probe = "local x = 1; x += 1; for i = 1, 2 do if i == 1 then continue end end"
    return subprocess.run([exe, "-e", probe], capture_output=True).returncode == 0


ENGINE_OK = _luajit_supports_pob()


def pytest_collection_modifyitems(config, items):
    if ENGINE_OK:
        return
    skip = pytest.mark.skip(reason="LuaJIT with PoB syntax support not installed (scripts/setup-engine.sh)")
    for item in items:
        if "engine" in item.keywords:
            item.add_marker(skip)


@pytest.fixture(scope="session")
def service():
    svc = PoBService(Engine(root=find_repo_root()))
    yield svc
    svc.engine.stop()
