import argparse
import json
from typing import Any, Dict

import openai
from jsonschema import validate, ValidationError

# Example function schema definitions
FUNCTIONS: Dict[str, Dict[str, Any]] = {
    "echo": {
        "description": "Return the provided text.",
        "parameters": {
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "Text to echo back"},
            },
            "required": ["text"],
        },
    },
}

MODEL = "gpt-3.5-turbo-0613"


def list_functions() -> None:
    for name, desc in FUNCTIONS.items():
        print(f"{name}: {desc.get('description', '')}")


def get_schema(name: str) -> Dict[str, Any]:
    if name not in FUNCTIONS:
        raise KeyError(f"Unknown function: {name}")
    return FUNCTIONS[name]["parameters"]


def validate_params(name: str, params: Dict[str, Any]) -> None:
    schema = get_schema(name)
    validate(params, schema)


def call_function(name: str, params: Dict[str, Any]) -> Dict[str, Any]:
    descriptor = {"name": name, **FUNCTIONS[name]}
    response = openai.ChatCompletion.create(
        model=MODEL,
        messages=[{"role": "user", "content": f"Call function {name}"}],
        functions=[descriptor],
        function_call={"name": name, "arguments": json.dumps(params)},
    )
    message = response["choices"][0]["message"]
    fc = message.get("function_call")
    if fc:
        return json.loads(fc.get("arguments", "{}"))
    return {}


def main() -> None:
    parser = argparse.ArgumentParser(description="Simple OpenAI function shell")
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("list", help="List available functions")

    schema_p = sub.add_parser("schema", help="Show JSON schema for function")
    schema_p.add_argument("name")

    call_p = sub.add_parser("call", help="Call a function")
    call_p.add_argument("name")
    call_p.add_argument("params", help="JSON encoded parameters")

    args = parser.parse_args()

    if args.cmd == "list":
        list_functions()
    elif args.cmd == "schema":
        print(json.dumps(get_schema(args.name), indent=2))
    elif args.cmd == "call":
        params = json.loads(args.params)
        try:
            validate_params(args.name, params)
        except ValidationError as e:
            print(f"Parameter validation failed: {e.message}")
            return
        result = call_function(args.name, params)
        print(json.dumps(result, indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
