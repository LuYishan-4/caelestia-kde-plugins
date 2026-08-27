#!/usr/bin/env python3
"""Regenerate the top-level ``index.json`` for the Caelestia plugin store.

The index is the machine-readable registry consumed by programs that ingest
the store (see ``docs/ingestion-contract.md``). CI runs this after every merge
to ``main`` so the committed index never drifts from the plugin folders.

Usage:
    python scripts/build_index.py
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate  # noqa: E402

INDEX_PATH = validate.REPO_ROOT / "index.json"


def build():
    schema = validate.load_json(validate.SCHEMA_PATH)
    entries = []
    for plugin_dir in validate.iter_plugin_dirs():
        metadata_path = plugin_dir / "metadata.json"
        if not metadata_path.is_file():
            print(f"error: {plugin_dir.name}: missing metadata.json", file=sys.stderr)
            return 1
        meta = validate.load_json(metadata_path)
        validate.validate(
            instance=meta, schema=schema, format_checker=validate.FormatChecker()
        )
        entry = {"id": meta["id"], "path": f"plugins/{plugin_dir.name}"}
        entry.update(meta)
        entries.append(entry)

    entries.sort(key=lambda entry: entry["id"])
    index = {
        "format": "caelestia-plugin-index",
        "version": 1,
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "plugins": entries,
    }
    INDEX_PATH.write_text(
        json.dumps(index, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {INDEX_PATH} ({len(entries)} plugin(s))")
    return 0


if __name__ == "__main__":
    sys.exit(build())
