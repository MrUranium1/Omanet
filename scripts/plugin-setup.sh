#!/usr/bin/env bash
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "OmaNet setup"
echo "============"
echo

if "$root/install.sh"; then
    status=0
    echo
    echo "Setup complete. Start sharing from the OmaNet bar icon."
else
    status=$?
    echo
    echo "Setup did not complete (exit $status). Review the messages above."
fi

echo
read -n1 -s -r -p "Press any key to close this window..." || true
echo
exit "$status"
