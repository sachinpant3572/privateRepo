#!/usr/bin/env bash
# Tiles images into labelled contact sheets (24 tiles each), so a batch of
# screenshots is read as a few sheets instead of many full images.
# Cloud stand-in for the desktop contactsheet.js; needs ImageMagick (montage).
#
#   tools/contactsheet.sh <folder or files...> --out <prefix> [--tile <px>] [--only <regex>]
#
# Writes <prefix>-1.png, <prefix>-2.png, ... and prints their paths.
set -euo pipefail
out="" tile=320 only="" inputs=()
while [ $# -gt 0 ]; do
	case "$1" in
		--out) out="$2"; shift 2 ;;
		--tile) tile="$2"; shift 2 ;;
		--only) only="$2"; shift 2 ;;
		*) inputs+=("$1"); shift ;;
	esac
done
[ -n "$out" ] && [ ${#inputs[@]} -gt 0 ] || { echo "usage: $0 <folder or files...> --out <prefix> [--tile px] [--only regex]" >&2; exit 2; }
files=()
for i in "${inputs[@]}"; do
	if [ -d "$i" ]; then
		while IFS= read -r f; do files+=("$f"); done < <(find "$i" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
	else
		files+=("$i")
	fi
done
if [ -n "$only" ]; then
	kept=()
	for f in "${files[@]}"; do [[ "$(basename "$f")" =~ $only ]] && kept+=("$f"); done
	files=("${kept[@]}")
fi
[ ${#files[@]} -gt 0 ] || { echo "no images found" >&2; exit 1; }
n=0
for ((s = 0; s < ${#files[@]}; s += 24)); do
	n=$((n + 1))
	montage -label '%t' "${files[@]:s:24}" -tile 6x -geometry "${tile}x$((tile * 9 / 16))+4+4" \
		-pointsize 14 -background '#222' -fill white "${out}-${n}.png"
	echo "${out}-${n}.png"
done
