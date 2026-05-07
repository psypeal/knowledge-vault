#!/bin/bash
# knowledge-vault: Build a bibliographic slug and disambiguate against existing files.
#   Sanitises (lowercase, ascii, hyphens), assembles "<entity>-<year>-<keyword>",
#   and appends -2/-3/... if the slug collides with raw/<slug>.md or originals/<slug>.*.
#
# Usage: bash derive-slug.sh <entity> <year> <keyword> [vault_dir]
#   entity   : first-author surname (paper) or org abbreviation (report)
#   year     : 4-digit year (or empty for unknown)
#   keyword  : 1-2 short title words
#   vault_dir: vault root, defaults to ".vault"
#
# Stdout: the final slug.
# Stderr: nothing on success.

set -euo pipefail

ENTITY="${1:?Usage: derive-slug.sh <entity> <year> <keyword> [vault_dir]}"
YEAR="${2:-}"
KEYWORD="${3:-}"
VAULT_DIR="${4:-.vault}"

python3 - "$ENTITY" "$YEAR" "$KEYWORD" "$VAULT_DIR" << 'PYEOF'
import os
import re
import sys
import unicodedata

entity, year, keyword, vault_dir = sys.argv[1:5]

def slugify(s: str) -> str:
    if not s:
        return ''
    # Strip accents -> ascii
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode('ascii')
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', '-', s).strip('-')
    return s

parts = [slugify(p) for p in (entity, year, keyword) if slugify(p)]
base = '-'.join(parts) or 'untitled'

raw_dir = os.path.join(vault_dir, 'raw')
originals_dir = os.path.join(vault_dir, 'originals')

def collides(slug: str) -> bool:
    if os.path.exists(os.path.join(raw_dir, slug + '.md')):
        return True
    if os.path.isdir(originals_dir):
        for f in os.listdir(originals_dir):
            if os.path.splitext(f)[0] == slug:
                return True
    return False

candidate = base
n = 2
while collides(candidate):
    candidate = f'{base}-{n}'
    n += 1

print(candidate)
PYEOF
