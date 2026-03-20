
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