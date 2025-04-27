#!/bin/sh

set -eu
# shellcheck disable=SC3044
shopt -u verbose_errexit 2>/dev/null ||:

# shellcheck source=lib/libexec/runner.sh
. "${SHELLSPEC_LIB:-./lib}/libexec/runner.sh"

start_profiler() {
  [ "$SHELLSPEC_PROFILER" ] || return 0
  $SHELLSPEC_SHELL "$SHELLSPEC_LIBEXEC/shellspec-profiler.sh" &
} 2>/dev/null

stop_profiler() {
  [ "$SHELLSPEC_PROFILER" ] || return 0
  if [ -e "$SHELLSPEC_PROFILER_SIGNAL" ]; then
    rm "$SHELLSPEC_PROFILER_SIGNAL"
  fi
}

cleanup() {
  "$SHELLSPEC_TRAP" '' INT
  set -- "$SHELLSPEC_TMPBASE" && SHELLSPEC_TMPBASE=''
  [ "$SHELLSPEC_KEEP_TMPDIR" ] && return 0
  [ "$1" ] || return 0
  { rmtempdir "$1" & } 2>/dev/null
}

interrupt() {
  "$SHELLSPEC_TRAP" '' TERM # Workaround for posh: Prevent display 'Terminated'.
  stop_profiler
  reporter_pid=''
  read_pid_file reporter_pid "$SHELLSPEC_REPORTER_PID" 0
  [ "$reporter_pid" ] && sleep_wait signal 0 "$reporter_pid" 2>/dev/null
  signal TERM 0 2>/dev/null &&:
  cleanup
  exit 130
}

precheck() {
  export VERSION="$SHELLSPEC_VERSION"
  export SHELL_VERSION="$SHELLSPEC_SHELL_VERSION"
  export SHELL_TYPE="$SHELLSPEC_SHELL_TYPE"

  eval "set -- $1"
  [ $# -gt 0 ] || return 0

  status_file=$SHELLSPEC_PRECHECKER_STATUS
  if [ $# -gt 0 ]; then
    for module in "$@"; do
      import_path=''
      resolve_module_path import_path "$module"
      if [ ! -r "$import_path" ]; then
        echo "Unable to load the required module '$module': $import_path" >&2
        exit 1
      fi
      set -- "$@" "$import_path"
      shift
    done
  fi
  prechecker="$SHELLSPEC_LIBEXEC/shellspec-prechecker.sh"
  # shellcheck disable=SC2086
  $SHELLSPEC_SHELL "$prechecker" --warn-fd=3 --status-file="$status_file" "$@"
}

executor() {
  start_profiler
  executor="$SHELLSPEC_LIBEXEC/shellspec-executor.sh"
  # shellcheck disable=SC2086
  $SHELLSPEC_SHELL "$SHELLSPEC_TIME" $SHELLSPEC_SHELL "$executor" "$@"
  eval "stop_profiler; return $?"
}

reporter() {
  $SHELLSPEC_SHELL "$SHELLSPEC_LIBEXEC/shellspec-reporter.sh" "$@"
}

error_handler() {
  error_count=0

  while IFS= read -r line; do
    # shellcheck disable=SC2004
    error_count=$(($error_count + 1))
    error "$line"
  done

  [ "$error_count" -eq 0 ] || exit "$SHELLSPEC_ERROR_EXIT_CODE"
}

"$SHELLSPEC_TRAP" 'interrupt' INT
"$SHELLSPEC_TRAP" ':' TERM
trap 'cleanup' EXIT

check_formatters() {
  eval "set -- $1"
  if [ $# -gt 0 ]; then
    for module in "$@"; do
      module_exists "${module}_formatter" && continue
      abort "The specified formatter '$module' is not found."
    done
  fi
}
check_formatters "$SHELLSPEC_FORMATTER $SHELLSPEC_GENERATORS"

if [ $# -gt 0 ]; then
  for p in "$@"; do
    [ -f "$p" ] || continue
    is_specfile "$p" && continue
    abort "File '$p' cannot be executed because it does not match the pattern '$SHELLSPEC_PATTERN'."
  done
fi

if [ "$SHELLSPEC_REPAIR" ]; then
  if [ -e "$SHELLSPEC_QUICK_FILE" ]; then
    SHELLSPEC_QUICK=1
  else
    warn "Quick Mode is disabled. Run with --quick option first."
    exit
  fi
fi

if [ "$SHELLSPEC_QUICK" ]; then
  if ! [ -e "$SHELLSPEC_QUICK_FILE" ]; then
    if ( : >| "$SHELLSPEC_QUICK_FILE" ) 2>/dev/null; then
      warn "Quick Mode is automatically enabled." \
        "If you want disable it, delete '$SHELLSPEC_QUICK_FILE'."
    else
      warn "Failed to enable Quick Mode " \
        "due to failed to create '$SHELLSPEC_QUICK_FILE'."
    fi
  fi

  if [ -e "$SHELLSPEC_QUICK_FILE" ]; then
    count=$# line='' last_line=''
    while read_quickfile line state "$SHELLSPEC_REPAIR"; do
      [ "$last_line" = "$line" ] && continue || last_line=$line
      match_quick_data "$line" "$@" && set -- "$@" "$line"
    done < "$SHELLSPEC_QUICK_FILE"
    if [ "$#" -gt "$count" ] && shift "$count"; then
      warn "Run only not-passed examples the last time they ran."
      export SHELLSPEC_PATTERN="*"
    elif [ "$SHELLSPEC_REPAIR" ]; then
      warn "No failed examples were found."
      exit
    fi
  fi
fi

quick_mode='' info='' info_extra=$SHELLSPEC_INFO
[ -e "$SHELLSPEC_QUICK_FILE" ] && quick_mode="<quick mode> "
[ "$SHELLSPEC_QUICK" ] && info="${info}--quick "
[ "$SHELLSPEC_REPAIR" ] && info="${info}--repair "
if [ "$SHELLSPEC_FAIL_FAST_COUNT" ]; then
  info="${info}--fail-fast $SHELLSPEC_FAIL_FAST_COUNT " && info="${info% 1 } "
fi
[ "$SHELLSPEC_WORKERS" -gt 0 ] && info="${info}--jobs $SHELLSPEC_WORKERS "
[ "$SHELLSPEC_DRYRUN" ] && info="${info}--dry-run "
[ "$SHELLSPEC_XTRACE" ] && info="${info}--trace${SHELLSPEC_XTRACE_ONLY:+-only} "
[ "$SHELLSPEC_RANDOM" ] && info="${info}--random $SHELLSPEC_RANDOM "
[ "$info" ] && info="{${info% }}"
SHELLSPEC_INFO="${quick_mode}${info}${info_extra:+ }${info_extra}"

mktempdir "$SHELLSPEC_TMPBASE"

if [ "$SHELLSPEC_KEEP_TMPDIR" ]; then
  warn "Keeping temporary directory."
  warn "Manually delete: rm -rf \"$SHELLSPEC_TMPBASE\""
fi

noexec_check="$SHELLSPEC_TMPBASE/.shellspec-check-executable"
echo '#!/bin/sh' >| "$noexec_check"
"$SHELLSPEC_CHMOD" +x "$noexec_check"
if ! "$noexec_check" 2>/dev/null; then
  export SHELLSPEC_NOEXEC_TMPDIR=1
  warn "Some features will not work properly because files under" \
    "the tmp directory (mounted with noexec option?) cannot be executed."
fi

if [ "$SHELLSPEC_BANNER" ]; then
  if [ -s "$SHELLSPEC_BANNER_FILE" ]; then
    cat "$SHELLSPEC_BANNER_FILE"
  elif [ -s "$SHELLSPEC_BANNER_FILE.md" ]; then
    cat "$SHELLSPEC_BANNER_FILE.md"
  fi
fi

if [ "${SHELLSPEC_RANDOM:-}" ]; then
  export SHELLSPEC_LIST="$SHELLSPEC_RANDOM"
  exec="$SHELLSPEC_LIBEXEC/shellspec-list.sh"
  eval "$SHELLSPEC_SHELL" "\"$exec\"" ${1+'"$@"'} >|"$SHELLSPEC_INFILE"
  set -- -
fi

xs=0
{
  # precheck outputs code such as environment variable settings via FD9
  env=$( ( ( ( ( set -- "$SHELLSPEC_REQUIRES"
    set +e; (set -e; precheck "$@") >&8 8>&-; echo "xs=$?" >&9
    ) 2>&1 | while IFS= read -r line; do error "$line"; done >&2
    ) 3>&1 | while IFS= read -r line; do warn "$line"; done >&2
    ) 4>&1 | while IFS= read -r line; do info "$line"; done >&8
  ) 9>&1 )
  eval "$env"
} 8>&1
if [ "$xs" -ne 0 ] || [ -s "$SHELLSPEC_PRECHECKER_STATUS" ]; then
  exit "$xs"
fi

xs1='' xs2='' xs3=''
set +e
{
  xs=$(
    (
      (
        (
          ( set -e; executor "$@" ) 3>&- 4>&- 5>&-
	  echo "xs1=$?" >&5
        ) | (
          ( set -e; reporter "$@" ) >&3 3>&- 4>&- 5>&-
          echo "xs2=$?" >&5
        )
      ) 2>&1 | (
        ( set -e; error_handler ) >&4 3>&- 4>&- 5>&-
        echo "xs3=$?" >&5
      )
    ) 5>&1
  )
} 3>&1 4>&2

eval "$xs"
xs='' error=''
for i in "$xs1" "$xs2" "$xs3"; do
  case $i in
    0) continue ;;
    "$SHELLSPEC_FAILURE_EXIT_CODE") [ "$xs" ] || xs=$i ;;
    "$SHELLSPEC_ERROR_EXIT_CODE") xs=$i error=1 && break ;;
    *) [ "${xs#"$SHELLSPEC_FAILURE_EXIT_CODE"}" ] || xs=$i; error=1
  esac
done
xs=${xs:-0}

if [ "$error" ]; then
  msg="Aborted with status code"
  error "$msg [executor: $xs1] [reporter: $xs2] [error handler: $xs3]"
fi

case $xs in
  0) ;; # Running specs exit with successfully.
  "$SHELLSPEC_FAILURE_EXIT_CODE") ;; # Running specs exit with failure.
  *) error "Fatal error occurred, terminated with exit status $xs."
esac

exit "$xs"
