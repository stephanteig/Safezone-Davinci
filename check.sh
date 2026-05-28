#!/bin/bash
# Syntax-check every .lua file in SafeZone/ and spec/.
# Uses Resolve's bundled fuscript interpreter (luac is not required).
# Exits non-zero if any parse errors are found.
# Usage: ./check.sh

FUSCRIPT="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript"

if [ ! -x "$FUSCRIPT" ]; then
    echo "ERROR: fuscript not found at expected path:"
    echo "  $FUSCRIPT"
    echo "Install DaVinci Resolve or set FUSCRIPT env var to the correct path."
    exit 1
fi

PASS=0
FAIL=0

while IFS= read -r -d '' f; do
    out=$("$FUSCRIPT" "$f" 2>&1)
    if echo "$out" | grep -qi "syntax error\|unexpected symbol\|<eof>"; then
        echo "FAIL: $f"
        echo "$out"
        FAIL=$((FAIL + 1))
    else
        echo "OK:   $f"
        PASS=$((PASS + 1))
    fi
done < <(find SafeZone spec -name "*.lua" -print0 2>/dev/null)

echo ""
echo "Syntax check: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
