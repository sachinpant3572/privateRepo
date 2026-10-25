#!/usr/bin/env bash
# Fails if any GDScript file in a Godot project has a compiler warning
# (shadowed names, unused variables, integer division, unreachable code...).
# Godot only prints warnings in the editor, so this copies the project,
# raises every default warning to an error and parse-checks each script.
# Usage: check_gdscript_warnings.sh <project dir>   (after `godot --import`)
set -euo pipefail

project="$1"
work="$(mktemp -d)"
cp -r "$project/." "$work/"

warnings=(
  unassigned_variable unassigned_variable_op_assign unused_variable
  unused_local_constant unused_private_class_variable unused_parameter
  unused_signal shadowed_variable shadowed_variable_base_class
  shadowed_global_identifier unreachable_code unreachable_pattern
  standalone_expression standalone_ternary incompatible_ternary
  static_called_on_instance redundant_static_unload redundant_await
  assert_always_true assert_always_false integer_division narrowing_conversion
  int_as_enum_without_cast int_as_enum_without_match enum_variable_without_default
  empty_file deprecated_keyword confusable_identifier confusable_local_declaration
  confusable_local_usage confusable_capture_reassignment inference_on_variant
  native_method_override get_node_default_without_onready onready_with_export
)
{
  echo
  echo "[debug]"
  echo
  for w in "${warnings[@]}"; do
    echo "gdscript/warnings/$w=2"
  done
} >> "$work/project.godot"

status=0
while IFS= read -r -d '' file; do
  rel="${file#"$work"/}"
  out="$(timeout 120 godot --headless --path "$work" --check-only --script "res://$rel" 2>&1 || true)"
  if grep -q "SCRIPT ERROR" <<< "$out"; then
    echo "== $rel"
    grep -A1 "SCRIPT ERROR" <<< "$out" | grep -v "^--$"
    status=1
  fi
done < <(find "$work" -name "*.gd" -not -path "*/.godot/*" -print0)

rm -rf "$work"
if [ "$status" -eq 0 ]; then
  echo "No GDScript warnings."
fi
exit "$status"
