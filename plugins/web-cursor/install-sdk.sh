#!/usr/bin/env bash
# Install an already extracted Ultralight SDK into the required ThirdParty
# directory. This script deliberately performs no network access or download.
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/extracted-ultralight-sdk" >&2
    exit 2
fi

source_dir=$(cd "$1" && pwd)
target_dir=$(cd "$(dirname "$0")" && pwd)/ThirdParty

if [ ! -f "$source_dir/include/AppCore/App.h" ] || \
   [ ! -f "$source_dir/bin/libUltralightCore.so" ] || \
   [ ! -d "$source_dir/resources" ]; then
    echo "Invalid SDK: expected include/AppCore/App.h, bin/libUltralightCore.so, and resources/." >&2
    exit 1
fi

if [ -e "$target_dir" ]; then
    echo "Refusing to overwrite existing $target_dir. Remove or rename it first." >&2
    exit 1
fi

mkdir "$target_dir"
cp -a "$source_dir"/. "$target_dir"/
echo "Ultralight SDK installed in $target_dir"
