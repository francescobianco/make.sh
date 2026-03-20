
# executor.sh - Recipe execution

# Run the recipe for a given target
make_sh_executor_run() {
  local target; target="$1"
  local safe; safe=$(make_sh_parser_sanitize "$target")

  # Get prerequisites for automatic variables
  local raw_prereqs; raw_prereqs=""
  eval "raw_prereqs=\${MAKE_PREREQS_${safe}:-}"
  make_sh_variables_export_all
  local prereqs; prereqs=$(make_sh_variables_expand "$raw_prereqs")

  # Set automatic variables
  make_sh_variables_set_auto "$target" "$prereqs"

  # Export all make variables so recipes can see them
  make_sh_variables_export_all

  # Set MAKE environment variable
  export MAKE="${MAKE_BINARY:-make.sh}"
  export MAKEFLAGS="${MAKE_MAKEFLAGS:-}"
  export MAKEFILE_LIST="${MAKE_MAKEFILE:-Makefile}"

  # Get recipe line count
  local count; count=0
  eval "count=\${MAKE_RECIPE_COUNT_${safe}:-0}"

  if [ "$count" = "0" ]; then
    # No recipe - nothing to do
    return 0
  fi

  # Print trace line if --trace is enabled
  if [ "${MAKE_FLAG_TRACE:-0}" = "1" ]; then
    local trace_file; trace_file=""
    local trace_line; trace_line=0
    eval "trace_file=\${MAKE_FILE_${safe}:-${MAKE_MAKEFILE:-Makefile}}"
    eval "trace_line=\${MAKE_LINE_${safe}:-0}"
    local trace_reason; trace_reason=""
    trace_reason=$(make_sh_resolver_trace_reason "$target" 2>/dev/null) || true
    if [ -n "$trace_reason" ]; then
      printf '%s:%s: %s\n' "$trace_file" "$trace_line" "$trace_reason"
    fi
  fi

  local line_num; line_num=1
  local exit_code; exit_code=0
  local overall_exit; overall_exit=0

  while [ "$line_num" -le "$count" ]; do
    local raw_line; raw_line=""
    eval "raw_line=\${MAKE_RECIPE_LINE_${safe}_${line_num}:-}"

    # Parse recipe line prefixes: @, -, +
    local silent_line; silent_line=0
    local ignore_error_line; ignore_error_line=0
    local force_exec; force_exec=0  # + means run even in dry-run mode

    local line; line="$raw_line"
    local parsing_prefix; parsing_prefix=1

    while [ "$parsing_prefix" = "1" ]; do
      case "$line" in
        "@"*)
          silent_line=1
          line="${line#@}"
          ;;
        "-"*)
          ignore_error_line=1
          line="${line#-}"
          ;;
        "+"*)
          force_exec=1
          line="${line#+}"
          ;;
        *)
          parsing_prefix=0
          ;;
      esac
    done

    # Expand variables in the line
    local expanded_line; expanded_line=""
    expanded_line=$(make_sh_variables_expand "$line")

    # Print the command unless silent
    if [ "${MAKE_FLAG_SILENT:-0}" = "0" ] && [ "$silent_line" = "0" ]; then
      printf '%s\n' "$expanded_line"
    fi

    # Execute unless dry-run (unless + prefix forces execution)
    if [ "${MAKE_FLAG_DRYRUN:-0}" = "0" ] || [ "$force_exec" = "1" ]; then
      # Execute using sh
      sh -c "$expanded_line"
      exit_code=$?

      if [ "$exit_code" != "0" ]; then
        if [ "${MAKE_FLAG_IGNORE_ERRORS:-0}" = "0" ] && [ "$ignore_error_line" = "0" ]; then
          printf 'make.sh: [%s] Error %s\n' "$target" "$exit_code" >&2
          if [ "${MAKE_FLAG_KEEP_GOING:-0}" = "0" ]; then
            return "$exit_code"
          else
            overall_exit="$exit_code"
          fi
        fi
        # With ignore errors, continue but note failure
      fi
    fi

    line_num=$((line_num + 1))
  done

  return "$overall_exit"
}

# Check if a target has any recipe
make_sh_executor_has_recipe() {
  local target; target="$1"
  local safe; safe=$(make_sh_parser_sanitize "$target")
  local count; count=0
  eval "count=\${MAKE_RECIPE_COUNT_${safe}:-0}"
  [ "$count" -gt "0" ]
}
