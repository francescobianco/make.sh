
# resolver.sh - Dependency resolution and rebuild detection

# Check if a target is phony
make_sh_resolver_is_phony() {
  local target; target="$1"
  local p; p=""
  for p in ${MAKE_PHONY:-}; do
    if [ "$p" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

# Check if a target needs to be rebuilt
# Returns 0 if rebuild needed, 1 if up-to-date
make_sh_resolver_needs_rebuild() {
  local target; target="$1"

  # Phony targets always need rebuilding
  if make_sh_resolver_is_phony "$target"; then
    return 0
  fi

  # If -B (always make) flag is set, always rebuild
  if [ "${MAKE_FLAG_ALWAYS_MAKE:-0}" = "1" ]; then
    return 0
  fi

  # If target file doesn't exist, needs rebuild
  if [ ! -f "$target" ]; then
    return 0
  fi

  # Check if any prerequisite is newer than target
  local safe; safe=$(make_sh_parser_sanitize "$target")
  local raw_prereqs; raw_prereqs=""
  eval "raw_prereqs=\${MAKE_PREREQS_${safe}:-}"
  make_sh_variables_export_all
  local prereqs; prereqs=$(make_sh_variables_expand "$raw_prereqs")

  local prereq; prereq=""
  for prereq in $prereqs; do
    # If prereq is a phony target, always rebuild
    if make_sh_resolver_is_phony "$prereq"; then
      return 0
    fi
    # If prereq file doesn't exist, it needs to be built (which triggers rebuild of target)
    if [ ! -f "$prereq" ]; then
      return 0
    fi
    # If prereq is newer than target
    if [ "$prereq" -nt "$target" ]; then
      return 0
    fi
  done

  # Up to date
  return 1
}

# Return the trace reason string for a target rebuild.
# Prints one of:
#   "target 'X' does not exist"
#   "update target 'X' due to: prereq1 prereq2"
# Returns 1 if the target is actually up-to-date (no rebuild needed).
make_sh_resolver_trace_reason() {
  local target; target="$1"

  # Phony targets always rebuild — reason is prereqs or just "phony"
  if make_sh_resolver_is_phony "$target"; then
    local safe; safe=$(make_sh_parser_sanitize "$target")
    local raw_prereqs; raw_prereqs=""
    eval "raw_prereqs=\${MAKE_PREREQS_${safe}:-}"
    make_sh_variables_export_all
    local prereqs; prereqs=$(make_sh_variables_expand "$raw_prereqs")
    if [ -n "$prereqs" ]; then
      printf "update target '%s' due to: %s" "$target" "$prereqs"
    else
      printf "target '%s' does not exist" "$target"
    fi
    return 0
  fi

  if [ "${MAKE_FLAG_ALWAYS_MAKE:-0}" = "1" ]; then
    printf "update target '%s' due to: -B flag" "$target"
    return 0
  fi

  # Target file does not exist
  if [ ! -f "$target" ]; then
    printf "target '%s' does not exist" "$target"
    return 0
  fi

  # Find which prerequisites triggered the rebuild
  local safe; safe=$(make_sh_parser_sanitize "$target")
  local raw_prereqs; raw_prereqs=""
  eval "raw_prereqs=\${MAKE_PREREQS_${safe}:-}"
  make_sh_variables_export_all
  local prereqs; prereqs=$(make_sh_variables_expand "$raw_prereqs")

  local newer; newer=""
  local prereq; prereq=""
  for prereq in $prereqs; do
    if make_sh_resolver_is_phony "$prereq"; then
      if [ -z "$newer" ]; then newer="$prereq"; else newer="$newer $prereq"; fi
      continue
    fi
    if [ ! -f "$prereq" ] || [ "$prereq" -nt "$target" ]; then
      if [ -z "$newer" ]; then newer="$prereq"; else newer="$newer $prereq"; fi
    fi
  done

  if [ -n "$newer" ]; then
    printf "update target '%s' due to: %s" "$target" "$newer"
    return 0
  fi

  # Up-to-date
  return 1
}

# DFS-based topological sort for dependency resolution
# Detects cycles. Outputs space-separated ordered build list to stdout.
# Uses global visited/stack sets (simulated via space-separated strings).
_make_sh_resolver_visited=""
_make_sh_resolver_in_stack=""
_make_sh_resolver_order=""

_make_sh_resolver_contains() {
  local list; list="$1"
  local item; item="$2"
  local x; x=""
  for x in $list; do
    if [ "$x" = "$item" ]; then return 0; fi
  done
  return 1
}

_make_sh_resolver_dfs() {
  local target; target="$1"

  # Check for cycle
  if _make_sh_resolver_contains "$_make_sh_resolver_in_stack" "$target"; then
    printf 'make.sh: Circular dependency detected for target: %s\n' "$target" >&2
    return 1
  fi

  # Already visited (and processed)
  if _make_sh_resolver_contains "$_make_sh_resolver_visited" "$target"; then
    return 0
  fi

  # Mark as in-stack
  _make_sh_resolver_in_stack="$_make_sh_resolver_in_stack $target"

  # Get prerequisites
  local safe; safe=$(make_sh_parser_sanitize "$target")
  local raw_prereqs; raw_prereqs=""
  eval "raw_prereqs=\${MAKE_PREREQS_${safe}:-}"
  make_sh_variables_export_all
  local prereqs; prereqs=$(make_sh_variables_expand "$raw_prereqs")

  # Recurse into prerequisites
  local prereq; prereq=""
  for prereq in $prereqs; do
    # Only recurse if this prereq is a known make target
    if _make_sh_resolver_contains "$MAKE_TARGETS" "$prereq"; then
      _make_sh_resolver_dfs "$prereq" || return 1
    fi
  done

  # Remove from stack
  local new_stack; new_stack=""
  local item; item=""
  for item in $_make_sh_resolver_in_stack; do
    if [ "$item" != "$target" ]; then
      new_stack="$new_stack $item"
    fi
  done
  _make_sh_resolver_in_stack="$new_stack"

  # Mark as visited
  _make_sh_resolver_visited="$_make_sh_resolver_visited $target"

  # Add to order
  if [ -z "$_make_sh_resolver_order" ]; then
    _make_sh_resolver_order="$target"
  else
    _make_sh_resolver_order="$_make_sh_resolver_order $target"
  fi

  return 0
}

# Resolve build order for a target using DFS
# Prints space-separated list of targets in build order (dependencies first)
make_sh_resolver_run() {
  local target; target="$1"

  _make_sh_resolver_visited=""
  _make_sh_resolver_in_stack=""
  _make_sh_resolver_order=""

  _make_sh_resolver_dfs "$target" || return 1

  printf '%s' "$_make_sh_resolver_order"
}
