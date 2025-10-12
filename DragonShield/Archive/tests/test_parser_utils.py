# Version 1.0
# History
# - 1.0: Tests for parser_utils.findParserScript helper.

from pathlib import Path
import sys
import pytest

SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from DragonShield.python_scripts import parser_utils


class DummyFM:
    def __init__(self, existing_path: str = ""):
        self.existing_path = existing_path
        self.calls = []

    def exists(self, path: str) -> bool:
        self.calls.append(path)
        return path == self.existing_path


def test_find_parser_first_candidate():
    expected = str(Path(parser_utils.__file__).resolve().parent / "credit_suisse_parser.py")
    fm = DummyFM(existing_path=expected)

    path, checked = parser_utils.findParserScript(fm)

    assert path == expected
    assert checked == [expected]


def test_find_parser_second_candidate():
    first = str(Path(parser_utils.__file__).resolve().parent / "credit_suisse_parser.py")
    second = str(Path(parser_utils.__file__).resolve().parents[3] / "python_scripts" / "credit_suisse_parser.py")
    fm = DummyFM(existing_path=second)

    path, checked = parser_utils.findParserScript(fm)

    assert path == second
    assert checked == [first, second]


def test_find_parser_missing():
    fm = DummyFM()
    with pytest.raises(FileNotFoundError) as exc:
        parser_utils.findParserScript(fm)

    msg = str(exc.value)
    assert "Parser script not found" in msg

