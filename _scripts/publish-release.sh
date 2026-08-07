#!/usr/bin/env bash
#
# Cut a release carrying every asset the site downloads at pre-render.
#
#   usage: _scripts/publish-release.sh vX.Y.Z [source_root]
#
# The site reads its databases and analysis CSVs from
# `releases/latest/download/`, which does not fall back to an older release: a
# release published without them breaks the next render. This script exists so
# that cannot happen by accident.
#
# `source_root` defaults to the pipeline output tree next door. Every name in
# _scripts/release-assets.txt is located by name underneath it, and nothing is
# created until all of them are found.
#
# Run it BEFORE pushing main, so the assets are in place when CI renders.

set -euo pipefail

tag=${1:-}
source_root=${2:-../multised-engine/data}

if [[ -z $tag ]]; then
  echo "usage: $0 vX.Y.Z [source_root]" >&2
  exit 64
fi

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
manifest=$here/release-assets.txt

# gh rejects --notes-from-tag together with --repo, so run from the repo root
# and let gh infer the repository from the git remote.
cd "$here/.."

if [[ ! -f $manifest ]]; then
  echo "missing manifest: $manifest" >&2
  exit 66
fi

files=()
missing=()
while read -r asset; do
  [[ -z $asset || $asset == \#* ]] && continue
  # -L: the engine's `data` is a symlink to external storage, and find will not
  # descend into one without it. Without -L every asset reports as missing.
  found=$(find -L "$source_root" -name "$asset" -type f -print -quit 2>/dev/null || true)
  if [[ -n $found ]]; then
    files+=("$found")
  else
    missing+=("$asset")
  fi
done < "$manifest"

if (( ${#missing[@]} )); then
  echo "not found under $source_root:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo >&2
  echo "Nothing was created. Build the missing outputs, or point at another" >&2
  echo "source root: $0 $tag /path/to/data" >&2
  exit 65
fi

echo "Publishing $tag with ${#files[@]} assets:"
printf '  %s\n' "${files[@]}"
echo

gh release create "$tag" \
  --title "multised (clean) $tag" \
  --notes-from-tag \
  "${files[@]}"
