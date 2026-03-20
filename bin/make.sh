#!/usr/bin/env bash
# @BP010: Release metadata
# @package: make.sh
# @build_type: bin
# @build_with: Mush v0.2.0 (2026-03-20 develop)
# @build_date: 2026-03-20T20:48:05Z
set -e
use() { return 0; }
extern() { return 0; }
legacy() { return 0; }
module() { return 0; }
public() { return 0; }
embed() { return 0; }
inject() { return 0; }
## BP004: Compile the entrypoint


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


usage() {
  cat <<'EOF'
Usage: make [options] [target] ...
Options:
  -b, -m                      Ignored for compatibility.
  -B, --always-make           Unconditionally make all targets.
  -C DIRECTORY, --directory=DIRECTORY
                              Change to DIRECTORY before doing anything.
  -d                          Print lots of debugging information.
  --debug[=FLAGS]             Print various types of debugging information.
  -e, --environment-overrides
                              Environment variables override makefiles.
  -E STRING, --eval=STRING    Evaluate STRING as a makefile statement.
  -f FILE, --file=FILE, --makefile=FILE
                              Read FILE as a makefile.
  -h, --help                  Print this message and exit.
  -i, --ignore-errors         Ignore errors from recipes.
  -I DIRECTORY, --include-dir=DIRECTORY
                              Search DIRECTORY for included makefiles.
  -j [N], --jobs[=N]          Allow N jobs at once; infinite jobs with no arg.
  -k, --keep-going            Keep going when some targets can't be made.
  -l [N], --load-average[=N], --max-load[=N]
                              Don't start multiple jobs unless load is below N.
  -L, --check-symlink-times   Use the latest mtime between symlinks and target.
  -n, --just-print, --dry-run, --recon
                              Don't actually run any recipe; just print them.
  -o FILE, --old-file=FILE, --assume-old=FILE
                              Consider FILE to be very old and don't remake it.
  -O[TYPE], --output-sync[=TYPE]
                              Synchronize output of parallel jobs by TYPE.
  -p, --print-data-base       Print make's internal database.
  -q, --question              Run no recipe; exit status says if up to date.
  -r, --no-builtin-rules      Disable the built-in implicit rules.
  -R, --no-builtin-variables  Disable the built-in variable settings.
  -s, --silent, --quiet       Don't echo recipes.
  --no-silent                 Echo recipes (disable --silent mode).
  -S, --no-keep-going, --stop
                              Turns off -k.
  -t, --touch                 Touch targets instead of remaking them.
  --trace                     Print tracing information.
  -v, --version               Print the version number of make and exit.
  -w, --print-directory       Print the current directory.
  --no-print-directory        Turn off -w, even if it was turned on implicitly.
  -W FILE, --what-if=FILE, --new-file=FILE, --assume-new=FILE
                              Consider FILE to be infinitely new.
  --warn-undefined-variables  Warn when an undefined variable is referenced.

This program built for x86_64-pc-linux-gnu
Report bugs to <bug-make@gnu.org>
EOF
}


# parser.sh - Makefile parser

# Sanitize a target/variable name to a valid shell variable suffix
make_sh_parser_sanitize() {
  printf '%s' "$1" | sed 's/[-. \/]/_/g'
}

# Initialize/reset parser state
make_sh_parser_init() {
  MAKE_TARGETS=""
  MAKE_PHONY=""
  MAKE_VAR_NAMES=""
  MAKE_CURRENT_TARGET=""
  MAKE_CURRENT_LINE=0
}

# Add a target to the targets list if not already present
make_sh_parser_add_target() {
  local t; t="$1"
  local safe; safe=$(make_sh_parser_sanitize "$t")

  # Check if already in list
  local found; found=0
  local existing; existing=""
  for existing in $MAKE_TARGETS; do
    if [ "$existing" = "$t" ]; then
      found=1
      break
    fi
  done

  if [ "$found" = "0" ]; then
    if [ -z "$MAKE_TARGETS" ]; then
      MAKE_TARGETS="$t"
    else
      MAKE_TARGETS="$MAKE_TARGETS $t"
    fi
    # Initialize recipe count
    eval "MAKE_RECIPE_COUNT_${safe}=0"
    eval "MAKE_PREREQS_${safe}=''"
  fi
}

# Append a recipe line to a target
make_sh_parser_add_recipe_line() {
  local target; target="$1"
  local line; line="$2"
  local safe; safe=$(make_sh_parser_sanitize "$target")

  local count; count=0
  eval "count=\${MAKE_RECIPE_COUNT_${safe}:-0}"
  local newcount; newcount=$((count + 1))
  eval "MAKE_RECIPE_COUNT_${safe}=$newcount"
  eval "MAKE_RECIPE_LINE_${safe}_${newcount}=\$line"
  # Store first recipe line number for --trace (GNU make reports this line)
  if [ "$count" = "0" ]; then
    eval "MAKE_LINE_${safe}=\$MAKE_CURRENT_LINE"
  fi
}

# Expand variables in a string using current MAKE_VAR_* state
# Simpler version used at parse time (only for prerequisites expansion)
make_sh_parser_expand_vars() {
  local str; str="$1"
  printf '%s' "$str" | awk '
  BEGIN {
    for (k in ENVIRON) {
      if (substr(k, 1, 9) == "MAKE_VAR_") {
        varname = substr(k, 10)
        vars[varname] = ENVIRON[k]
      }
    }
  }
  {
    line = $0
    out = ""
    i = 1
    n = length(line)
    while (i <= n) {
      c = substr(line, i, 1)
      if (c == "$" && i < n) {
        nc = substr(line, i+1, 1)
        if (nc == "(") {
          j = index(substr(line, i+2), ")")
          if (j > 0) {
            varname = substr(line, i+2, j-1)
            safe = varname
            gsub(/[-. \/]/, "_", safe)
            if (safe in vars) { out = out vars[safe] }
            i = i + 2 + j
            continue
          }
        }
        if (nc == "{") {
          j = index(substr(line, i+2), "}")
          if (j > 0) {
            varname = substr(line, i+2, j-1)
            safe = varname
            gsub(/[-. \/]/, "_", safe)
            if (safe in vars) { out = out vars[safe] }
            i = i + 2 + j
            continue
          }
        }
        out = out c nc
        i += 2
        continue
      }
      out = out c
      i++
    }
    print out
  }
  '
}

# Process an include directive
make_sh_parser_include() {
  local inc_file; inc_file="$1"
  local base_dir; base_dir="$2"

  # Try absolute, then relative to base_dir
  if [ -f "$inc_file" ]; then
    make_sh_parser_load "$inc_file"
  elif [ -f "${base_dir}/${inc_file}" ]; then
    make_sh_parser_load "${base_dir}/${inc_file}"
  fi
}

# Main parser function: reads a Makefile and populates global state
make_sh_parser_load() {
  local file; file="$1"
  local base_dir; base_dir=$(dirname "$file")

  if [ ! -f "$file" ]; then
    printf 'make.sh: %s: No such file or directory\n' "$file" >&2
    return 1
  fi

  MAKE_CURRENT_TARGET=""

  # We read the file line by line using a while loop
  # We need to handle continuation lines (ending with \)
  local raw_line; raw_line=""
  local line; line=""
  local continued; continued=""
  continued=0

  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    MAKE_CURRENT_LINE=$((MAKE_CURRENT_LINE + 1))

    # Handle line continuation
    if [ "$continued" = "1" ]; then
      # Remove leading whitespace from continuation
      local trimmed; trimmed=$(printf '%s' "$raw_line" | sed 's/^[[:space:]]*//')
      line="${line} ${trimmed}"
    else
      line="$raw_line"
    fi

    # Check if line ends with backslash (continuation)
    case "$line" in
      *\\)
        line=$(printf '%s' "$line" | sed 's/\\$//')
        continued=1
        continue
        ;;
    esac
    continued=0

    # Check if this is a recipe line (starts with TAB)
    case "$raw_line" in
      "	"*)
        # Recipe line (TAB-prefixed)
        if [ -n "$MAKE_CURRENT_TARGET" ]; then
          # Strip the leading TAB
          local recipe_line; recipe_line="${raw_line#	}"
          make_sh_parser_add_recipe_line "$MAKE_CURRENT_TARGET" "$recipe_line"
        fi
        # Reset line and continue - don't process as rule/var
        line=""
        continue
        ;;
    esac

    # Strip inline comments (but not in recipe lines)
    # Only strip # that are not inside variable references
    # Simple approach: strip from # onwards (GNU make does this)
    # But we must be careful: don't strip # inside $(...)
    # For simplicity, strip # that appears outside of $(...) ${...}
    case "$line" in
      *"#"*)
        line=$(printf '%s' "$line" | sed 's/[[:space:]]*#.*$//')
        ;;
    esac

    # Skip empty lines
    case "$line" in
      ""|*[\ ]*) ;;
    esac
    if [ -z "$(printf '%s' "$line" | tr -d '[:space:]')" ]; then
      MAKE_CURRENT_TARGET=""
      line=""
      continue
    fi

    # Check for include directive
    case "$line" in
      include\ *|-include\ *|sinclude\ *)
        local inc_file; inc_file=$(printf '%s' "$line" | sed 's/^[-s]*include[[:space:]]*//')
        inc_file=$(make_sh_parser_expand_vars "$inc_file")
        make_sh_parser_include "$inc_file" "$base_dir"
        MAKE_CURRENT_TARGET=""
        line=""
        continue
        ;;
    esac

    # Check for .PHONY
    case "$line" in
      ".PHONY:"*|".PHONY :"*)
        local phony_list; phony_list=$(printf '%s' "$line" | sed 's/^\.PHONY[[:space:]]*:[[:space:]]*//')
        local pt; pt=""
        for pt in $phony_list; do
          if [ -z "$MAKE_PHONY" ]; then
            MAKE_PHONY="$pt"
          else
            # Check for duplicates
            local already; already=0
            local ep; ep=""
            for ep in $MAKE_PHONY; do
              if [ "$ep" = "$pt" ]; then already=1; break; fi
            done
            if [ "$already" = "0" ]; then
              MAKE_PHONY="$MAKE_PHONY $pt"
            fi
          fi
        done
        MAKE_CURRENT_TARGET=""
        line=""
        continue
        ;;
    esac

    # Check for .SUFFIXES, .DEFAULT, .PRECIOUS, .INTERMEDIATE (special targets we ignore)
    case "$line" in
      ".SUFFIXES"*|".DEFAULT"*|".PRECIOUS"*|".INTERMEDIATE"*|".SECONDARY"*|".DELETE_ON_ERROR"*|".EXPORT_ALL_VARIABLES"*|".NOTPARALLEL"*|".ONESHELL"*|".POSIX"*)
        MAKE_CURRENT_TARGET=""
        line=""
        continue
        ;;
    esac

    # Check for variable assignment
    # Patterns: VAR = val, VAR := val, VAR ::= val, VAR ?= val, VAR += val
    # Must check before rule detection
    local var_name; var_name=""
    local var_op; var_op=""
    local var_val; var_val=""

    case "$line" in
      *"::="*)
        var_name=$(printf '%s' "$line" | sed 's/[[:space:]]*::=.*$//')
        var_op="::="
        var_val=$(printf '%s' "$line" | sed 's/^[^:]*::=[[:space:]]*//')
        ;;
      *":="*)
        var_name=$(printf '%s' "$line" | sed 's/[[:space:]]*:=.*$//')
        var_op=":="
        var_val=$(printf '%s' "$line" | sed 's/^[^:]*:=[[:space:]]*//')
        ;;
      *"?="*)
        var_name=$(printf '%s' "$line" | sed 's/[[:space:]]*?=.*$//')
        var_op="?="
        var_val=$(printf '%s' "$line" | sed 's/^[^?]*?=[[:space:]]*//')
        ;;
      *"+="*)
        var_name=$(printf '%s' "$line" | sed 's/[[:space:]]*+=.*$//')
        var_op="+="
        var_val=$(printf '%s' "$line" | sed 's/^[^+]*+=[[:space:]]*//')
        ;;
    esac

    # Handle simple = assignment (must not match := etc.)
    if [ -z "$var_op" ]; then
      case "$line" in
        *"="*)
          # Make sure it's not a rule (rules contain :)
          local before_eq; before_eq=$(printf '%s' "$line" | cut -d'=' -f1)
          case "$before_eq" in
            *":"*)
              # Could be a rule with = in prereqs, not an assignment
              var_op=""
              ;;
            *)
              var_name=$(printf '%s' "$before_eq" | sed 's/[[:space:]]*$//')
              var_op="="
              var_val=$(printf '%s' "$line" | sed 's/^[^=]*=[[:space:]]*//')
              ;;
          esac
          ;;
      esac
    fi

    # Validate var_name: must not contain spaces (after trimming)
    if [ -n "$var_op" ] && [ -n "$var_name" ]; then
      var_name=$(printf '%s' "$var_name" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      # var_name should be a valid identifier (letters, digits, underscore, dot, dash)
      case "$var_name" in
        *" "*|*"	"*|"")
          var_op=""
          ;;
      esac
    fi

    if [ -n "$var_op" ] && [ -n "$var_name" ]; then
      local safe_vname; safe_vname=$(make_sh_parser_sanitize "$var_name")
      local expanded_val; expanded_val=""

      case "$var_op" in
        ":="|"::=")
          # Immediate expansion
          expanded_val=$(make_sh_parser_expand_vars "$var_val")
          eval "MAKE_VAR_${safe_vname}=\$expanded_val"
          ;;
        "?=")
          # Set only if not already set
          local existing_val; existing_val=""
          eval "existing_val=\${MAKE_VAR_${safe_vname}:-__NOTSET__}"
          if [ "$existing_val" = "__NOTSET__" ]; then
            eval "MAKE_VAR_${safe_vname}=\$var_val"
          fi
          ;;
        "+=")
          # Append
          local current_val; current_val=""
          eval "current_val=\${MAKE_VAR_${safe_vname}:-}"
          if [ -z "$current_val" ]; then
            eval "MAKE_VAR_${safe_vname}=\$var_val"
          else
            eval "MAKE_VAR_${safe_vname}=\"\${current_val} \${var_val}\""
          fi
          ;;
        "=")
          # Recursive (deferred) expansion - store as-is
          eval "MAKE_VAR_${safe_vname}=\$var_val"
          ;;
      esac

      # Track var name in MAKE_VAR_NAMES
      local vn_found; vn_found=0
      local vn; vn=""
      for vn in $MAKE_VAR_NAMES; do
        if [ "$vn" = "$var_name" ]; then vn_found=1; break; fi
      done
      if [ "$vn_found" = "0" ]; then
        if [ -z "$MAKE_VAR_NAMES" ]; then
          MAKE_VAR_NAMES="$var_name"
        else
          MAKE_VAR_NAMES="$MAKE_VAR_NAMES $var_name"
        fi
      fi

      MAKE_CURRENT_TARGET=""
      line=""
      continue
    fi

    # Check for rule definition: target: prereqs
    case "$line" in
      *":"*)
        # Check it's not an export/unexport/override/define
        case "$line" in
          export\ *|unexport\ *|override\ *|define\ *|endef*)
            MAKE_CURRENT_TARGET=""
            line=""
            continue
            ;;
        esac

        local rule_target; rule_target=$(printf '%s' "$line" | cut -d':' -f1 | sed 's/[[:space:]]*$//')
        local rule_prereqs; rule_prereqs=$(printf '%s' "$line" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

        # Skip if target is empty
        if [ -z "$rule_target" ]; then
          MAKE_CURRENT_TARGET=""
          line=""
          continue
        fi

        # Handle double-colon rules (treat as single colon for now)
        case "$rule_target" in
          *":")
            rule_target=$(printf '%s' "$rule_target" | sed 's/:$//')
            ;;
        esac

        # Handle multiple targets on LHS (space-separated)
        local tgt; tgt=""
        for tgt in $rule_target; do
          make_sh_parser_add_target "$tgt"
          local safe_t; safe_t=$(make_sh_parser_sanitize "$tgt")
          # Expand prereqs at parse time for := style, but store as-is for deferred
          eval "MAKE_PREREQS_${safe_t}=\$rule_prereqs"
          # Store source file for --trace (line number stored on first recipe line)
          eval "MAKE_FILE_${safe_t}=\$file"
        done

        # Set current target to first one for recipe accumulation
        MAKE_CURRENT_TARGET=$(printf '%s' "$rule_target" | awk '{print $1}')
        line=""
        continue
        ;;
    esac

    # Any other line resets current target context
    MAKE_CURRENT_TARGET=""
    line=""
  done < "$file"
}

# Get prerequisites for a target (expands variables)
make_sh_parser_get_prereqs() {
  local target; target="$1"
  local safe; safe=$(make_sh_parser_sanitize "$target")
  local raw_prereqs; raw_prereqs=""
  eval "raw_prereqs=\${MAKE_PREREQS_${safe}:-}"
  # Export MAKE_VAR_* so awk can see them, then expand
  make_sh_variables_export_all
  make_sh_variables_expand "$raw_prereqs"
}


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

  # Check prerequisites first — they take priority over "does not exist"
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

  # No contributing prereqs: target file simply does not exist
  if [ ! -f "$target" ]; then
    printf "target '%s' does not exist" "$target"
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


# variables.sh - Make variable handling

# Sanitize a name to a valid shell variable suffix
make_sh_variables_sanitize_name() {
  local name; name="$1"
  # Replace -, ., /, space with _
  printf '%s' "$name" | sed 's/[-. \/]/_/g'
}

# Set a make variable
make_sh_variables_set() {
  local name; name="$1"
  local value; value="$2"
  local safe; safe=$(make_sh_variables_sanitize_name "$name")
  eval "MAKE_VAR_${safe}=\$value"
}

# Get a make variable value (prints to stdout)
make_sh_variables_get() {
  local name; name="$1"
  local safe; safe=$(make_sh_variables_sanitize_name "$name")
  eval "printf '%s' \"\${MAKE_VAR_${safe}:-}\""
}

# Expand $(VAR) and ${VAR} references in a string
# Also handles automatic variables if set in env
make_sh_variables_expand() {
  local str; str="$1"
  local result; result=""
  local max_passes; max_passes=20
  local pass; pass=0
  local prev; prev=""

  # Iteratively expand until stable (handles nested expansions)
  result="$str"
  while [ $pass -lt $max_passes ]; do
    prev="$result"
    # Expand $@ $< $^ $* $? (automatic variables from environment)
    # These are set by the executor before calling expand
    # We use a python-free, awk-based approach

    result=$(printf '%s' "$result" | awk '
    BEGIN {
      # Load all MAKE_VAR_* environment variables
      for (k in ENVIRON) {
        if (substr(k, 1, 9) == "MAKE_VAR_") {
          varname = substr(k, 10)
          vars[varname] = ENVIRON[k]
        }
      }
      # Load automatic variables
      auto_at  = ENVIRON["MAKE_AUTO_AT"]
      auto_lt  = ENVIRON["MAKE_AUTO_LESS"]
      auto_caret = ENVIRON["MAKE_AUTO_CARET"]
      auto_star = ENVIRON["MAKE_AUTO_STAR"]
      auto_q   = ENVIRON["MAKE_AUTO_QUESTION"]
    }
    {
      line = $0
      out = ""
      i = 1
      n = length(line)
      while (i <= n) {
        c = substr(line, i, 1)
        if (c == "$" && i < n) {
          nc = substr(line, i+1, 1)
          if (nc == "@") { out = out auto_at; i += 2; continue }
          if (nc == "<") { out = out auto_lt; i += 2; continue }
          if (nc == "^") { out = out auto_caret; i += 2; continue }
          if (nc == "*") { out = out auto_star; i += 2; continue }
          if (nc == "?") { out = out auto_q; i += 2; continue }
          if (nc == "$") { out = out "$"; i += 2; continue }
          if (nc == "(") {
            # find closing )
            j = index(substr(line, i+2), ")")
            if (j > 0) {
              varname = substr(line, i+2, j-1)
              # sanitize: replace - . / space with _
              safe = varname
              gsub(/[-. \/]/, "_", safe)
              if (safe in vars) {
                out = out vars[safe]
              }
              i = i + 2 + j
              continue
            }
          }
          if (nc == "{") {
            # find closing }
            j = index(substr(line, i+2), "}")
            if (j > 0) {
              varname = substr(line, i+2, j-1)
              safe = varname
              gsub(/[-. \/]/, "_", safe)
              if (safe in vars) {
                out = out vars[safe]
              }
              i = i + 2 + j
              continue
            }
          }
          # single char variable (not a special one we handle)
          out = out c nc
          i += 2
          continue
        }
        out = out c
        i++
      }
      print out
    }
    ' )

    if [ "$result" = "$prev" ]; then
      break
    fi
    pass=$((pass + 1))
  done

  printf '%s' "$result"
}

# Export all MAKE_VAR_* as environment variables (for use in recipe subshells)
make_sh_variables_export_all() {
  local var; var=""
  # We iterate over known variable names stored in MAKE_VAR_NAMES
  local names; names="${MAKE_VAR_NAMES:-}"
  local name; name=""
  for name in $names; do
    local safe; safe=$(make_sh_variables_sanitize_name "$name")
    local value; value=""
    eval "value=\${MAKE_VAR_${safe}:-}"
    export "MAKE_VAR_${safe}=$value"
  done
}

# Set automatic variables for a target execution context
make_sh_variables_set_auto() {
  local target; target="$1"
  local prereqs; prereqs="$2"
  local first_prereq; first_prereq=""
  local newer_prereqs; newer_prereqs=""

  # Get first prereq
  first_prereq=$(printf '%s' "$prereqs" | cut -d' ' -f1)

  # Compute newer prereqs ($? - prereqs newer than target)
  if [ -f "$target" ]; then
    local p; p=""
    for p in $prereqs; do
      if [ -f "$p" ] && [ "$p" -nt "$target" ]; then
        if [ -z "$newer_prereqs" ]; then
          newer_prereqs="$p"
        else
          newer_prereqs="$newer_prereqs $p"
        fi
      elif [ ! -f "$p" ]; then
        # non-file prereqs are always considered newer
        if [ -z "$newer_prereqs" ]; then
          newer_prereqs="$p"
        else
          newer_prereqs="$newer_prereqs $p"
        fi
      fi
    done
  else
    newer_prereqs="$prereqs"
  fi

  export MAKE_AUTO_AT="$target"
  export MAKE_AUTO_LESS="$first_prereq"
  export MAKE_AUTO_CARET="$prereqs"
  export MAKE_AUTO_STAR=""
  export MAKE_AUTO_QUESTION="$newer_prereqs"
}
## BP005: Execute the entrypoint
main "$@"
