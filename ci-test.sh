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
    echo && echo "## Testing core (no validation, no Stacked Borrows, symbolic alignment)" && echo
    MIRIFLAGS="-Zmiri-disable-validation -Zmiri-disable-stacked-borrows -Zmiri-symbolic-alignment-check" \
             ./run-test.sh core --all-targets -- --skip align 2>&1 | ts -i '%.s  '
    echo && echo "## Testing core (strict provenance)" && echo
    MIRIFLAGS="-Zmiri-strict-provenance" \
             ./run-test.sh core --all-targets 2>&1 | ts -i '%.s  '
    # FIXME: No strict provenance because of portable-simd scatter/gather (https://github.com/rust-lang/portable-simd/issues/271)
    echo && echo "## Testing core docs" && echo
    MIRIFLAGS="-Zmiri-ignore-leaks -Zmiri-disable-isolation" \
             ./run-test.sh core --doc
    ;;
alloc)
    echo && echo "## Testing alloc (symbolic alignment, strict provenance)" && echo
    MIRIFLAGS="-Zmiri-symbolic-alignment-check -Zmiri-strict-provenance" \
             ./run-test.sh alloc --all-targets 2>&1 | ts -i '%.s  '
    echo && echo "## Testing alloc docs (strict provenance)" && echo
    MIRIFLAGS="-Zmiri-ignore-leaks -Zmiri-disable-isolation -Zmiri-strict-provenance" \
             ./run-test.sh alloc --doc
    ;;
simd)
    cd $MIRI_LIB_SRC/portable-simd
    echo && echo "## Testing portable-simd (strict provenance)" && echo
    MIRIFLAGS="-Zmiri-strict-provenance" \
      cargo miri test --all-targets
    # FIXME: No strict provenance because of scatter/gather (https://github.com/rust-lang/portable-simd/issues/271)
    echo && echo "## Testing portable-simd docs" && echo
    MIRIFLAGS="" \
      cargo miri test --doc
    ;;
more)
    cd more_tests
    # FIXME: No strict provenance due to MPSC bug (https://github.com/rust-lang/rust/pull/95621)
    echo && echo "## Testing more" && echo
    MIRIFLAGS="-Zmiri-disable-isolation" \
      cargo miri test
    ;;
*)
    echo "Unknown command"
    exit 1
esac
