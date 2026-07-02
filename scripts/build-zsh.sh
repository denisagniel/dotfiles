#!/usr/bin/env bash
# Build zsh from source into ~/.local — for servers with no zsh and no sudo.
# Tested target: RHEL 9 (gcc/make present, ncurses runtime libs present,
# ncurses-devel headers absent). Safe to re-run; skips work already done.
#
#   Usage:  bash scripts/build-zsh.sh
#
# Logs land in ~/.local/src/*.log so failures are diagnosable after the fact.
set -uo pipefail

PREFIX="$HOME/.local"
SRC="$PREFIX/src"
VER=5.9
mkdir -p "$PREFIX/bin" "$PREFIX/lib" "$PREFIX/include" "$SRC"
cd "$SRC" || exit 1

echo "== [1/5] fetch zsh $VER source =="
# Release tarballs (with a pre-generated ./configure) from several mirrors.
# SourceForge 403s bots, so send a browser UA. Debian's orig tarball is the
# most reliable, unblocked mirror. We validate the download is real xz before
# trusting it (a 403/404 HTML error page would otherwise slip through).
UA="Mozilla/5.0 (X11; Linux x86_64)"
URLS=(
    "https://deb.debian.org/debian/pool/main/z/zsh/zsh_${VER}.orig.tar.xz"
    "https://downloads.sourceforge.net/project/zsh/zsh/${VER}/zsh-${VER}.tar.xz"
    "https://sourceforge.net/projects/zsh/files/zsh/${VER}/zsh-${VER}.tar.xz/download"
    "https://www.zsh.org/pub/zsh-${VER}.tar.xz"
)
TARBALL="zsh-$VER.tar.xz"
valid_xz() { [ -s "$1" ] && head -c6 "$1" | grep -q $'\xfd7zXZ'; }

if ! valid_xz "$TARBALL"; then
    rm -f "$TARBALL"
    for u in "${URLS[@]}"; do
        echo "  trying: $u"
        curl -fL -A "$UA" -o "$TARBALL" "$u" 2>/dev/null || true
        if valid_xz "$TARBALL"; then echo "  got valid tarball from: $u"; break; fi
        rm -f "$TARBALL"
    done
fi
if ! valid_xz "$TARBALL"; then
    echo "FETCH FAILED: no mirror returned a valid zsh $VER tarball"; exit 1
fi

rm -rf "zsh-$VER"
tar xf "$TARBALL"
# Extracted top dir can be zsh-5.9 (release) or zsh-$VER (Debian). Detect it.
d=$(tar tf "$TARBALL" 2>/dev/null | head -1 | cut -d/ -f1)
cd "$d" || { echo "cannot enter extracted dir '$d'"; exit 1; }
echo "  building in: $PWD"

echo "== [2/5] provide ncurses libs + headers (no sudo) =="
# zsh's configure looks for lib<name>.so; RHEL ships only versioned .so.6/.so.5.
# Symlink them into ~/.local/lib so the linker can find them.
for l in ncursesw tinfo ncurses; do
    for cand in "/usr/lib64/lib$l.so.6" "/usr/lib64/lib$l.so.5"; do
        [ -e "$cand" ] && ln -sf "$cand" "$PREFIX/lib/lib$l.so" && break
    done
done
# Headers: fetch (not install) the ncurses-devel RPM as a normal user and
# extract just the headers into ~/.local/include.
if [ ! -e "$PREFIX/include/ncurses.h" ] && [ ! -e /usr/include/ncurses.h ]; then
    rm -rf "$SRC/rpmextract" && mkdir -p "$SRC/rpmextract" && cd "$SRC/rpmextract"
    ( dnf download ncurses-devel 2>/dev/null || yumdownloader ncurses-devel 2>/dev/null ) || true
    rpm=$(ls -1 ncurses-devel*.rpm 2>/dev/null | head -1)
    if [ -n "${rpm:-}" ]; then
        rpm2cpio "$rpm" | cpio -idm >/dev/null 2>&1
        cp -a usr/include/* "$PREFIX/include/" 2>/dev/null \
            && echo "  headers installed -> $PREFIX/include"
    else
        echo "  WARN: could not fetch ncurses-devel headers; configure may fail"
    fi
    cd "$SRC/zsh-$VER" || exit 1
fi

echo "== [3/5] configure =="
# Most release tarballs ship ./configure. If not (rare), regenerate it.
if [ ! -x ./configure ]; then
    echo "  no ./configure found; running Util/preconfig / autoreconf"
    if [ -x ./Util/preconfig ]; then ./Util/preconfig >/dev/null 2>&1; fi
    [ -x ./configure ] || autoreconf -i >/dev/null 2>&1 || true
fi
[ -x ./configure ] || { echo "no ./configure and could not generate one"; exit 1; }
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib -L/usr/lib64 -Wl,-rpath,/usr/lib64 -Wl,-rpath,$PREFIX/lib"
./configure --prefix="$PREFIX" --enable-multibyte --with-tcsetpgrp \
    > "$SRC/configure.log" 2>&1
cfg=$?
echo "  configure exit: $cfg  (full log: $SRC/configure.log)"
tail -15 "$SRC/configure.log"
[ "$cfg" -ne 0 ] && { echo "CONFIGURE FAILED"; exit 1; }

echo "== [4/5] make =="
make -j"$(nproc 2>/dev/null || echo 2)" > "$SRC/make.log" 2>&1
mk=$?
echo "  make exit: $mk"
tail -8 "$SRC/make.log"
[ "$mk" -ne 0 ] && { echo "MAKE FAILED"; exit 1; }

echo "== [5/5] install =="
make install > "$SRC/install.log" 2>&1
echo "  install exit: $?"

echo "=================== RESULT ==================="
if "$PREFIX/bin/zsh" --version; then
    echo "SUCCESS: zsh is at $PREFIX/bin/zsh"
else
    echo "zsh build did NOT produce a working binary; inspect logs in $SRC"
    exit 1
fi
