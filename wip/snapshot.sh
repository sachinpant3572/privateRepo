#!/usr/bin/env bash
# Saves each phase-3 builder worktree's work (commits since its base plus
# uncommitted and untracked files) as wip/snapshots/<pkg>.patch on the main
# branch, so a wiped container loses nothing. Uses a temp index: the
# builder's own index is not touched. Apply on a fresh base with
#   git apply --3way wip/snapshots/<pkg>.patch
set -eu
root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
mkdir -p "$root/wip/snapshots"
# worktree dir suffix -> package letter (agent ids of session 3)
declare -A pkg=([a51e54d60601755b1]=G [a33a1bd59f718629f]=P [a9c0ec2e48144bf73]=R)
for id in "${!pkg[@]}"; do
	w="$root/.claude/worktrees/agent-$id"
	[ -d "$w" ] || { echo "${pkg[$id]}: no worktree"; continue; }
	idx=$(mktemp)
	GIT_INDEX_FILE=$idx git -C "$w" read-tree HEAD
	GIT_INDEX_FILE=$idx git -C "$w" add -A -- . ':!*.uid' ':!.godot'
	out="$root/wip/snapshots/${pkg[$id]}.patch"
	GIT_INDEX_FILE=$idx git -C "$w" diff --cached --binary fe9f7ec > "$out"
	rm -f "$idx"
	echo "${pkg[$id]}: $(grep -c '^diff --git' "$out") files, $(wc -l < "$out") lines"
done
