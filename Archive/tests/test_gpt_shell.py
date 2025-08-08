import json

from pathlib import Path
import pytest
import types
import sys

SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

# Provide stub openai module if not installed
if "openai" not in sys.modules:
    sys.modules["openai"] = types.SimpleNamespace(ChatCompletion=types.SimpleNamespace(create=lambda **_: None))
if "jsonschema" not in sys.modules:
    sys.modules["jsonschema"] = types.SimpleNamespace(validate=lambda *a, **k: None, ValidationError=Exception)

from DragonShield.python_scripts import gpt_shell


def test_get_schema():
    schema = gpt_shell.get_schema("echo")
    assert "properties" in schema


def test_validate_and_call(monkeypatch):
    called = {}

    def fake_create(**kwargs):
        called.update(kwargs)
        return {
            "choices": [
                {
                    "message": {
                        "function_call": {
                            "arguments": json.dumps({"text": "hi"})
                        }
                    }
                }
            ]
        }

    monkeypatch.setattr(gpt_shell.openai.ChatCompletion, "create", fake_create)

    params = {"text": "hi"}
    gpt_shell.validate_params("echo", params)
    result = gpt_shell.call_function("echo", params)

    assert result == {"text": "hi"}
    assert called["function_call"]["name"] == "echo"



