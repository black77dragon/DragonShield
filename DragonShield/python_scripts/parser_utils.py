# python_scripts/parser_utils.py

# MARK: - Version 1.0
# MARK: - History
# - 1.0: Initial creation with helper to locate bundled parser script.

from pathlib import Path
from typing import Tuple, List, Protocol


class FileManagerProtocol(Protocol):
    def exists(self, path: str) -> bool:
        ...


class DefaultFileManager:
    @staticmethod
    def exists(path: str) -> bool:  # pragma: no cover - simple wrapper
        return Path(path).exists()


def findParserScript(file_manager: FileManagerProtocol = DefaultFileManager()) -> Tuple[str, List[str]]:
    """Return the path to the bundled parser script and list of checked paths."""
    script_name = "zkb_parser.py"
    module_dir = Path(__file__).resolve().parent
    project_dir = module_dir.parents[2]
    candidates = [
        module_dir / script_name,
        project_dir / 'python_scripts' / script_name,
    ]
    checked: List[str] = []
    for path in candidates:
        path_str = str(path)
        checked.append(path_str)
        if file_manager.exists(path_str):
            return path_str, checked
    raise FileNotFoundError(f"Parser script not found. Checked: {checked}")
