#!/bin/bash
set -euo pipefail

# apply our patch
rm -rf rust-src-patched
cp -a $(rustc --print sysroot)/lib/rustlib/src/rust/ rust-src-patched
( cd rust-src-patched && patch -f -p1 < ../rust-src.diff )
export MIRI_LIB_SRC=$(pwd)/rust-src-patched/library

# run the tests (some also without validation, to exercise those code paths in Miri)
case "$1" in
core)
    #echo && echo "## Testing core (no validation, no Stacked Borrows, symbolic alignment)" && echo
    #MIRIFLAGS="-Zmiri-disable-validation -Zmiri-disable-stacked-borrows -Zmiri-symbolic-alignment-check" \
    #         ./run-test.sh core --lib --tests -- --skip align 2>&1 | ts -i '%.s  '
    #echo && echo "## Testing core (strict provenance)" && echo
    #MIRIFLAGS="-Zmiri-strict-provenance" \
    #         ./run-test.sh core --lib --tests 2>&1 | ts -i '%.s  '
    # Cannot use strict provenance as there are int-to-ptr casts in the doctests.
    ./run-test.sh core --doc atomic
    echo && echo "## Testing core docs" && echo
    MIRIFLAGS="-Zmiri-ignore-leaks -Zmiri-disable-isolation" \
             ./run-test.sh core --doc
    ;;
*)
    exit 0
esac
