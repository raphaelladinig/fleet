import json
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path

import plyvel

# --check exit codes: 0 matches, 1 differs, CHECK_FAILED could not inspect.
CHECK_FAILED = 2
# chrome.storage.sync limits from Chromium's extensions/common/api/storage.json.
QUOTA_BYTES = 102400
QUOTA_BYTES_PER_ITEM = 8192
MAX_ITEMS = 512
LEGACY_KEYS = (b"siteList", b"siteListEnabled", b"applyToListedOnly")


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
        if len(chunk_key(key, len(chunks))) + size + char_size > QUOTA_BYTES_PER_ITEM:
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
        if sync and len(key) + len(serialized) > QUOTA_BYTES_PER_ITEM:
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


def fits_sync_quota(database, settings):
    # Chromium's quota enforcer counts every item in the store after the write.
    items = dict(database.iterator())
    items.update(settings)
    total = sum(len(key) + len(sync_json(json.loads(value))) for key, value in items.items())
    return total <= QUOTA_BYTES and len(items) <= MAX_ITEMS


def synced_settings(database):
    # Join split values the way Dark Reader's readSyncStorage does.
    items = {key: json.loads(value) for key, value in database.iterator()}
    chunks = set()
    for key, value in list(items.items()):
        if isinstance(value, dict) and "__meta_split_count" in value:
            parts = [chunk_key(key, index) for index in range(value["__meta_split_count"])]
            chunks.update(parts)
            items[key] = json.loads("".join(items[part] for part in parts))
    return {
        key: sync_json(value)
        for key, value in items.items()
        if key not in chunks and key not in LEGACY_KEYS
    }


def pending_writes(local, sync):
    local_settings = pending_settings(local, False)
    sync_enabled = json.loads(local.get(b"syncSettings") or b"null")
    if sync_enabled is not None and not sync_enabled:
        # Dark Reader reads only the local store while sync is off.
        return local_settings, {}
    sync_settings = pending_settings(sync, True)
    if fits_sync_quota(sync, sync_settings):
        return local_settings, sync_settings
    # Match Dark Reader's fallback when sync rejects a write: turn sync off and
    # save the settings it read from sync, with full lists, to the local store.
    settings = synced_settings(sync)
    settings.update(pending_settings(sync, False))
    settings[b"syncSettings"] = b"false"
    return {key: value for key, value in settings.items() if local.get(key) != value}, {}


@contextmanager
def open_store(path, check):
    if path.is_symlink():
        raise ValueError(f"Refusing to open symlink: {path}")
    if not check:
        path.parent.mkdir(parents=True, exist_ok=True)
        with plyvel.DB(str(path), create_if_missing=True) as database:
            yield database
        return
    # Read a copy because a running Helium holds the database lock.
    with tempfile.TemporaryDirectory() as directory:
        copy = Path(directory) / "database"
        missing = not path.exists()
        if not missing:
            shutil.copytree(path, copy, ignore=shutil.ignore_patterns("LOCK"))
        # A missing store reads as empty, as the writer would create it.
        with plyvel.DB(str(copy), create_if_missing=missing) as database:
            yield database


def main(check, profile):
    extension_id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"
    local_path = profile / "Local Extension Settings" / extension_id
    sync_path = profile / "Sync Extension Settings" / extension_id
    # Open both stores before reporting drift, so a read error takes precedence.
    with open_store(local_path, check) as local, open_store(sync_path, check) as sync:
        local_settings, sync_settings = pending_writes(local, sync)
        if check:
            drift = bool(local_settings or sync_settings)
        else:
            for database, settings in ((local, local_settings), (sync, sync_settings)):
                with database.write_batch(sync=True) as batch:
                    for key, value in settings.items():
                        batch.put(key, value)
    if check:
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
