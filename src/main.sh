
module usage
module parser
module resolver
module executor
module variables

# Version string
MAKE_SH_VERSION="0.1.0 (make.sh - POSIX sh GNU Make clone)"

main() {
  # Default flags
  MAKE_FLAG_DRYRUN=0
  MAKE_FLAG_SILENT=0
  MAKE_FLAG_IGNORE_ERRORS=0
  MAKE_FLAG_KEEP_GOING=0
  MAKE_FLAG_ALWAYS_MAKE=0
  MAKE_FLAG_PRINT_DIR=0
  MAKE_FLAG_TRACE=0
  MAKE_MAKEFILE=""
  MAKE_DIR=""
  MAKE_TARGETS_CLI=""
  MAKE_MAKEFLAGS=""
  MAKE_BINARY="$0"

  # Collect any -C dir changes to apply before loading makefile
  local change_dir; change_dir=""

  # Parse arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version|-v)
        printf 'GNU Make %s\n' "$MAKE_SH_VERSION"
        printf 'Built for POSIX sh\n'
        printf 'This program is a POSIX sh clone of GNU Make.\n'
        return 0
        ;;
      --help|-h)
        usage
        return 0
        ;;
      -f|--file|--makefile)
        shift
        MAKE_MAKEFILE="$1"
        ;;
      --file=*|--makefile=*)
        MAKE_MAKEFILE="${1#*=}"
        ;;
      -f*)
        MAKE_MAKEFILE="${1#-f}"
        ;;
      -C|--directory)
        shift
        change_dir="$1"
        ;;
      --directory=*)
        change_dir="${1#*=}"
        ;;
      -C*)
        change_dir="${1#-C}"
        ;;
      -n|--just-print|--dry-run|--recon)
        MAKE_FLAG_DRYRUN=1
        MAKE_MAKEFLAGS="${MAKE_MAKEFLAGS}n"
        ;;
      -s|--silent|--quiet)
        MAKE_FLAG_SILENT=1
        MAKE_MAKEFLAGS="${MAKE_MAKEFLAGS}s"
        ;;
      -i|--ignore-errors)
        MAKE_FLAG_IGNORE_ERRORS=1
        MAKE_MAKEFLAGS="${MAKE_MAKEFLAGS}i"
        ;;
      -k|--keep-going)
        MAKE_FLAG_KEEP_GOING=1
        MAKE_MAKEFLAGS="${MAKE_MAKEFLAGS}k"
        ;;
      -B|--always-make)
        MAKE_FLAG_ALWAYS_MAKE=1
        MAKE_MAKEFLAGS="${MAKE_MAKEFLAGS}B"
        ;;
      -w|--print-directory)
        MAKE_FLAG_PRINT_DIR=1
        ;;
      --no-print-directory)
        MAKE_FLAG_PRINT_DIR=0
        ;;
      -e|--environment-overrides)
        # TODO: environment overrides
        ;;
      -b|-m)
        # Ignored for compatibility
        ;;
      -S|--no-keep-going|--stop)
        MAKE_FLAG_KEEP_GOING=0
        ;;
      --no-silent)
        MAKE_FLAG_SILENT=0
        ;;
      -j|--jobs)
        # We don't implement parallelism, just accept the flag
        case "$2" in
          [0-9]*)
            shift
            ;;
        esac
        ;;
      --jobs=*)
        ;;
      -r|--no-builtin-rules)
        ;;
      -R|--no-builtin-variables)
        ;;
      -p|--print-data-base)
        ;;
      -q|--question)
        # TODO: question mode
        ;;
      -t|--touch)
        # TODO: touch mode
        ;;
      --trace)
        MAKE_FLAG_TRACE=1
        ;;
      -d|--debug|--debug=*)
        ;;
      -I|--include-dir)
        shift
        ;;
      --include-dir=*)
        ;;
      -o|--old-file|--assume-old)
        shift
        ;;
      -W|--what-if|--new-file|--assume-new)
        shift
        ;;
      -l|--load-average|--max-load)
        case "$2" in
          [0-9]*)
            shift
            ;;
        esac
        ;;
      -E|--eval)
        shift
        ;;
      --eval=*)
        ;;
      -L|--check-symlink-times)
        ;;
      -O|--output-sync|--output-sync=*)
        ;;
      --warn-undefined-variables)
        ;;
      -*=*)
        # Variable assignment via command line (VAR=val)
        local cli_var; cli_var="${1%%=*}"
        local cli_val; cli_val="${1#*=}"
        # Remove leading - if present (it's an option=value)
        ;;
      *=*)
        # Variable override: VAR=value on command line
        local cv_name; cv_name="${1%%=*}"
        local cv_val; cv_val="${1#*=}"
        make_sh_variables_set "$cv_name" "$cv_val"
        local cv_safe; cv_safe=$(make_sh_parser_sanitize "$cv_name")
        export "MAKE_VAR_${cv_safe}=${cv_val}"
        ;;
      -*)
        printf 'make.sh: Unknown option: %s\n' "$1" >&2
        ;;
      *)
        # It's a target
        if [ -z "$MAKE_TARGETS_CLI" ]; then
          MAKE_TARGETS_CLI="$1"
        else
          MAKE_TARGETS_CLI="$MAKE_TARGETS_CLI $1"
        fi
        ;;
    esac
    shift
  done

  # Change directory if requested
  if [ -n "$change_dir" ]; then
    cd "$change_dir" || {
      printf 'make.sh: Cannot change directory to %s\n' "$change_dir" >&2
      return 1
    }
    if [ "${MAKE_FLAG_PRINT_DIR:-0}" = "1" ]; then
      printf 'make.sh: Entering directory `%s'"'"'\n' "$(pwd)"
    fi
  fi

  # Find makefile if not specified
  if [ -z "$MAKE_MAKEFILE" ]; then
    if [ -f "GNUmakefile" ]; then
      MAKE_MAKEFILE="GNUmakefile"
    elif [ -f "makefile" ]; then
      MAKE_MAKEFILE="makefile"
    elif [ -f "Makefile" ]; then
      MAKE_MAKEFILE="Makefile"
    else
      printf 'make.sh: No makefile found\n' >&2
      return 1
    fi
  fi

  # Initialize parser state
  make_sh_parser_init

  # Load the makefile
  if ! make_sh_parser_load "$MAKE_MAKEFILE"; then
    return 1
  fi

  # Determine targets to build
  local targets_to_build; targets_to_build=""

  if [ -n "$MAKE_TARGETS_CLI" ]; then
    targets_to_build="$MAKE_TARGETS_CLI"
  else
    # Default target: first target that doesn't start with '.'
    local t; t=""
    for t in $MAKE_TARGETS; do
      case "$t" in
        "."*)
          continue
          ;;
        *)
          targets_to_build="$t"
          break
          ;;
      esac
    done

    if [ -z "$targets_to_build" ]; then
      printf 'make.sh: No targets found in %s\n' "$MAKE_MAKEFILE" >&2
      return 1
    fi
  fi

  # Export MAKE_MAKEFILE for recipes
  export MAKE_MAKEFILE

  # Build each requested target
  local build_exit; build_exit=0
  local req_target; req_target=""

  for req_target in $targets_to_build; do
    # Resolve dependency order
    local order; order=""
    order=$(make_sh_resolver_run "$req_target") || {
      printf 'make.sh: Failed to resolve dependencies for %s\n' "$req_target" >&2
      if [ "${MAKE_FLAG_KEEP_GOING:-0}" = "0" ]; then
        return 1
      fi
      build_exit=1
      continue
    }

    # Execute each target in order
    local build_target; build_target=""
    for build_target in $order; do
      # Check if target needs rebuild
      if ! make_sh_resolver_needs_rebuild "$build_target"; then
        # Target is up-to-date - only print message for the top-level requested target
        if [ "$build_target" = "$req_target" ] && ! make_sh_resolver_is_phony "$build_target"; then
          printf "make: '%s' is up to date.\n" "$build_target"
        fi
        continue
      fi

      # Execute the recipe
      if make_sh_executor_has_recipe "$build_target"; then
        make_sh_executor_run "$build_target" || {
          local err; err=$?
          if [ "${MAKE_FLAG_KEEP_GOING:-0}" = "0" ]; then
            return "$err"
          fi
          build_exit="$err"
        }
      else
        # No recipe and no file: error (unless it's just a dependency with no rule needed)
        if ! make_sh_resolver_is_phony "$build_target" && [ ! -f "$build_target" ]; then
          # Check if it's a known target with no recipe (that's ok if it has prereqs only)
          local safe_bt; safe_bt=$(make_sh_parser_sanitize "$build_target")
          local bt_count; bt_count=0
          eval "bt_count=\${MAKE_RECIPE_COUNT_${safe_bt}:-0}"
          # If target is in MAKE_TARGETS it was explicitly defined
          local is_known; is_known=0
          local kt; kt=""
          for kt in $MAKE_TARGETS; do
            if [ "$kt" = "$build_target" ]; then is_known=1; break; fi
          done
          if [ "$is_known" = "0" ]; then
            printf "make.sh: No rule to make target '%s'\n" "$build_target" >&2
            if [ "${MAKE_FLAG_KEEP_GOING:-0}" = "0" ]; then
              return 1
            fi
            build_exit=1
          fi
        fi
      fi
    done
  done

  if [ -n "$change_dir" ] && [ "${MAKE_FLAG_PRINT_DIR:-0}" = "1" ]; then
    printf 'make.sh: Leaving directory `%s'"'"'\n' "$(pwd)"
  fi

  return "$build_exit"
}
