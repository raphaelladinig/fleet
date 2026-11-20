import json
import shutil
import sys
import tempfile
from pathlib import Path

import plyvel

# --check exit codes: 0 matches, 1 differs, CHECK_FAILED could not inspect.
CHECK_FAILED = 2


def chunk_key(key, index):
    suffix = ""
    while index:
        index, digit = divmod(index, 36)
        suffix = "0123456789abcdefghijklmnopqrstuvwxyz"[digit] + suffix
    return key + b"_" + (suffix or "0").encode()


def sync_json(value):
    # Match Chromium's JSON writer, which the sync quota measures.
    text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    for char in "<\u2028\u2029":
        text = text.replace(char, f"\\u{ord(char):04X}")
    return text.encode()


def split_for_sync(key, text):
    # Keep each chunk key plus its JSON string within QUOTA_BYTES_PER_ITEM.
    chunks = []
    start, size = 0, 2
    for end, char in enumerate(text):
        char_size = len(sync_json(char)) - 2
        if len(chunk_key(key, len(chunks))) + size + char_size > 8192:
            chunks.append(text[start:end])
            start, size = end, 2
        size += char_size
    chunks.append(text[start:])
    return chunks


def migrate_site_lists(database, sync):
    settings = {b"schemeVersion": b"2"}
    only_listed = json.loads(database.get(b"applyToListedOnly") or b"false")
    lists = {
        b"enabledFor": b"siteList" if only_listed else b"siteListEnabled",
        b"disabledFor": None if only_listed else b"siteList",
    }
    for key, legacy_key in lists.items():
        if database.get(key) is not None:
            continue
        value = json.loads(database.get(legacy_key) or b"null") if legacy_key else None
        if isinstance(value, dict) and "__meta_split_count" in value:
            value = json.loads(
                "".join(
                    json.loads(database.get(chunk_key(legacy_key, index)))
                    for index in range(value["__meta_split_count"])
                )
            )
        serialized = sync_json(value if value is not None else [])
        # Match Dark Reader's base-36 chunk keys, which it joins before parsing.
        if sync and len(key) + len(serialized) > 8192:
            chunks = split_for_sync(key, serialized.decode())
            for index, chunk in enumerate(chunks):
                settings[chunk_key(key, index)] = sync_json(chunk)
            serialized = sync_json({"__meta_split_count": len(chunks)})
        settings[key] = serialized
    return settings


def pending_settings(database, sync):
    settings = {b"enabledByDefault": b"false"}
    version = json.loads(database.get(b"schemeVersion") or b"0") or 0
    if int(version) < 2:
        # Preserve list meanings before enforcing the new mode.
        settings.update(migrate_site_lists(database, sync))
    return {key: value for key, value in settings.items() if database.get(key) != value}


def main(check, profile):
    extension_id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"
    drift = False
    for storage in ("Local Extension Settings", "Sync Extension Settings"):
        path = profile / storage / extension_id
        sync = storage == "Sync Extension Settings"
        if path.is_symlink():
            raise ValueError(f"Refusing to open symlink: {path}")
        if check:
            # The writer creates a missing store.
            if not path.exists():
                drift = True
                continue
            # Read a copy because a running Helium holds the database lock.
            with tempfile.TemporaryDirectory() as directory:
                copy = Path(directory) / "database"
                shutil.copytree(path, copy, ignore=shutil.ignore_patterns("LOCK"))
                with plyvel.DB(str(copy)) as database:
                    if pending_settings(database, sync):
                        drift = True
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        with plyvel.DB(str(path), create_if_missing=True) as database:
            settings = pending_settings(database, sync)
            with database.write_batch(sync=True) as batch:
                for key, value in settings.items():
                    batch.put(key, value)
    if check:
        # Inspect every store before reporting drift, so a read error takes precedence.
        sys.exit(1 if drift else 0)


if __name__ == "__main__":
    check = sys.argv[1:2] == ["--check"]
    try:
        main(check, Path(sys.argv[-1]))
    except Exception as error:
        if not check:
            raise
        print(f"Could not inspect Dark Reader stores in {sys.argv[-1]}: {error}", file=sys.stderr)
        sys.exit(CHECK_FAILED)
