import copy
import json
import os
import sys
import tempfile
from pathlib import Path

# --check exit codes: 0 matches, 1 differs, CHECK_FAILED could not inspect.
CHECK_FAILED = 2


def merge(target, settings):
    for key, value in settings.items():
        if isinstance(value, dict):
            if not isinstance(target.get(key), dict):
                target[key] = {}
            merge(target[key], value)
        elif isinstance(value, list) and isinstance(target.get(key), list):
            # Declared items are required members; keep the browser's extras and order.
            target[key].extend(item for item in value if item not in target[key])
        else:
            target[key] = copy.deepcopy(value)


def seed(target, settings):
    for key, value in settings.items():
        if key not in target:
            target[key] = copy.deepcopy(value)
        elif isinstance(value, dict) and isinstance(target[key], dict):
            seed(target[key], value)


def canonical(value):
    return json.dumps(value, sort_keys=True)


def main(check, arguments):
    seed_settings = {}
    if arguments[:1] == ["--seed"]:
        seed_settings = json.loads(Path(arguments[1]).read_text())
        arguments = arguments[2:]
    path = Path(arguments[0])
    settings = json.loads(Path(arguments[1]).read_text())
    if path.is_symlink():
        raise ValueError(f"Refusing to replace symlink: {path}")
    preferences = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(preferences, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    original = canonical(preferences)
    merge(preferences, settings)
    if check:
        # Seed-only keys never count as drift.
        sys.exit(0 if canonical(preferences) == original else 1)
    seed(preferences, seed_settings)
    if canonical(preferences) == original:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
            temporary = output.name
            json.dump(preferences, output, separators=(",", ":"))
            output.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    check = sys.argv[1:2] == ["--check"]
    try:
        main(check, sys.argv[2:] if check else sys.argv[1:])
    except Exception as error:
        if not check:
            raise
        print(f"Could not inspect {sys.argv[-2]}: {error}", file=sys.stderr)
        sys.exit(CHECK_FAILED)
