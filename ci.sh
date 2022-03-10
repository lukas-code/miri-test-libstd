#!/bin/bash
set -euo pipefail

# apply our patch
rm -rf rust-src-patched
cp -a $(rustc --print sysroot)/lib/rustlib/src/rust/ rust-src-patched
( cd rust-src-patched && patch -f -p1 < ../rust-src.diff )
export MIRI_LIB_SRC=$(pwd)/rust-src-patched/library

# run the tests (some also without validation, to exercise those code paths in Miri)

# portable-simd
echo && echo "## Testing portable-simd" && echo
(cd $MIRI_LIB_SRC/portable-simd/crates && cargo miri test --test i32_ops)

# libcore
echo && echo "## Testing core (no validation, no Stacked Borrows, symbolic alignment)" && echo
MIRIFLAGS="-Zmiri-disable-validation -Zmiri-disable-stacked-borrows -Zmiri-symbolic-alignment-check" \
  ./run-test.sh core --all-targets -- --skip align 2>&1 | ts -i '%.s  '
echo && echo "## Testing core (number validity)" && echo
MIRIFLAGS="-Zmiri-check-number-validity" \
  ./run-test.sh core --all-targets 2>&1 | ts -i '%.s  '
echo && echo "## Testing core (doctests)" && echo
MIRIFLAGS="-Zmiri-ignore-leaks -Zmiri-disable-isolation -Zmiri-check-number-validity" \
  ./run-test.sh core --doc

# liballoc
echo && echo "## Testing alloc (symbolic alignment, number validity)" && echo
MIRIFLAGS="-Zmiri-symbolic-alignment-check -Zmiri-check-number-validity" \
  ./run-test.sh alloc --all-targets 2>&1 | ts -i '%.s  '
echo && echo "## Testing alloc (doctests)" && echo
MIRIFLAGS="-Zmiri-ignore-leaks -Zmiri-disable-isolation -Zmiri-check-number-validity" \
  ./run-test.sh alloc --doc
