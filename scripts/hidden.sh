#!/usr/bin/env bash
# Runs a command on a display of its own that nobody sees: a headless KWin
# (drawing on the GPU, so shaders and pictures look as on screen), its own
# session bus and its own runtime folder. Nothing it opens reaches the
# person's desktop: no window, no tray icon, no notification, no sound.
#
#   scripts/hidden.sh [--size 1440x1000] -- <command> [args…]
#   scripts/hidden.sh -- env SOL_PREVIEW=1 SOL_SHOT=/tmp/x.png ./target/debug/terra
#
# Use it for every screenshot, drive and preview run. A preview in here
# reads its screens from the checkouts (SOL_QML_LIVE=1, src/live.rs), so an
# edited .qml shows on the next run without a build; SOL_QML_LIVE=0 looks
# at the compiled ones.
set -euo pipefail
export SOL_QML_LIVE=${SOL_QML_LIVE:-1}

size=1440x1000
if [[ ${1:-} == --size ]]; then size=$2; shift 2; fi
[[ ${1:-} == -- ]] && shift
[[ $# -gt 0 ]] || { echo "usage: $0 [--size WxH] -- <command> [args…]" >&2; exit 64; }
command -v kwin_wayland >/dev/null || { echo "needs kwin_wayland (the kwin package)" >&2; exit 69; }

run=$(mktemp -d "${TMPDIR:-/tmp}/sol-hidden.XXXXXX")
chmod 700 "$run"
# The document portal mounts a folder in there; let go of it before removing the rest.
trap 'fusermount3 -u "$run/doc" 2>/dev/null || fusermount -u "$run/doc" 2>/dev/null || true; rm -rf "$run" 2>/dev/null || true' EXIT
export XDG_RUNTIME_DIR=$run
unset DISPLAY WAYLAND_SOCKET

# The inner script starts the compositor, waits for its socket, runs the command and stops the compositor.
status=0
dbus-run-session -- bash -c '
	size=$1; shift
	kwin_wayland --virtual --width "${size%x*}" --height "${size#*x}" --socket hidden \
		--no-lockscreen --no-global-shortcuts >"$XDG_RUNTIME_DIR/kwin.log" 2>&1 &
	kwin=$!
	for _ in $(seq 100); do [[ -S $XDG_RUNTIME_DIR/hidden ]] && break; sleep 0.1; done
	[[ -S $XDG_RUNTIME_DIR/hidden ]] || { echo "the hidden display did not start:" >&2; cat "$XDG_RUNTIME_DIR/kwin.log" >&2; exit 70; }
	status=0
	WAYLAND_DISPLAY=hidden QT_QPA_PLATFORM=wayland "$@" || status=$?
	kill "$kwin" 2>/dev/null || true
	wait "$kwin" 2>/dev/null || true
	exit "$status"
' hidden "$size" "$@" || status=$?
exit "$status"
