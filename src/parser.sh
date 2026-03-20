
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
