#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
python3 -m unittest discover -s . -p 'test_*.py'
python3 -m json.tool manifest.json >/dev/null
bash -n check.sh
