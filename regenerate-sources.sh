#!/usr/bin/env bash
# Regenerates the generated dependency files next to the manifest.
# Needs: python3 with aiohttp, tomlkit, pyyaml, requirements-parser, packaging,
# a checkout of https://github.com/flatpak/flatpak-builder-tools in $FBT, and
# `flatpak-node-generator` (from $FBT/node) on PATH.
# Run from a directory holding checkouts of fontra and fontra-rcjk at the pinned
# commits (fontra-rcjk with its fontra submodule initialised).
set -euo pipefail
FBT=${FBT:?set FBT to your flatpak-builder-tools checkout}
OUT=$(pwd)

python3 "$FBT/pip/flatpak-pip-generator.py" --output "$OUT/python3-build-tools" --yaml \
  "setuptools>=77.0.1" wheel pkgconfig pybind11 "cython>=3.2.9,<3.3" \
  setuptools_git_ls_files setuptools_scm packaging hatchling hatch-vcs \
  setuptools-rust scikit-build

# skia-pathops, sr-aef and fontc are intentionally left out here: they are installed from
# their upstream wheels (one entry per architecture) by hand in the manifest.
# python3-deps.yaml is the generator output merged into a single module by hand (one pip call, cffsubr split out).
# cffsubr is a separate hand-written module in the manifest (offline cmake/ninja stubs, ANTLR4 zip, setuptools 80.9.0).
# Pins follow the Fontra Pak release: fontra-pak/requirements.txt, fontra/requirements.txt and
# fontra-compile/requirements.txt at the commits pinned in the manifest.
python3 "$FBT/pip/flatpak-pip-generator.py" --output "$OUT/python3-deps" --yaml \
  aiohttp==3.14.4 cattrs==26.2.1 "fonttools[ufo,unicode,woff]==4.68.0" anyio pyyaml==6.0.3 \
  ufomerge==1.9.8 pillow==13.0.0 ufo2ft==3.9.0 ufoLib2==0.18.1 fontmake==3.12.2 \
  booleanOperations==0.10.0 "glyphsLib==6.15.0" psutil==7.2.2 certifi==2026.10.19

# Fontra's package-lock.json lacks resolved/integrity for many packages; fill them in first
# (fix-lockfile.py is shipped next to this script), then generate from the patched lock.
python3 "$OUT/fix-lockfile.py" fontra/package-lock.json "$OUT/package-lock-fontra.json"
(cd fontra && cp "$OUT/package-lock-fontra.json" package-lock.json && flatpak-node-generator npm package-lock.json -o "$OUT/node-sources-fontra.json" && git checkout package-lock.json)
# fontra-rcjk's lockfile can lag behind its fontra submodule: re-lock against the submodule, then fill in resolved/integrity.
(cd fontra-rcjk && npm install --package-lock-only --ignore-scripts --no-audit --no-fund \
  && python3 "$OUT/fix-lockfile.py" package-lock.json "$OUT/package-lock-rcjk.json" \
  && cp "$OUT/package-lock-rcjk.json" package-lock.json \
  && flatpak-node-generator npm package-lock.json -o "$OUT/node-sources-rcjk.json" && git checkout package-lock.json)

# Cargo.lock files come from the maturin and watchfiles sdists named in the manifest.
python3 "$FBT/cargo/flatpak-cargo-generator.py" maturin-1.15.0/Cargo.lock -o "$OUT/cargo-sources-maturin.json"
python3 "$FBT/cargo/flatpak-cargo-generator.py" watchfiles-1.3.0/Cargo.lock -o "$OUT/cargo-sources-watchfiles.json"
