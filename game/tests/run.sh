#!/usr/bin/env bash
# Runs the headless prototype tests. Fails on any test failure or script error.
set -u
cd "$(dirname "$0")/.."
godot --headless --import >/dev/null 2>&1
out=$(timeout 750 godot --headless --fixed-fps 60 res://tests/test_runner.tscn 2>&1)
code=$?
echo "$out" | grep -vE "^\s*$|^Godot Engine"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR"; then
	echo "Script errors found"
	exit 1
fi
exit $code
