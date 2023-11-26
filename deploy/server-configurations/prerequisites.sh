#!/usr/bin/env bash

set -u

set -o pipefail

script_options=("$@")

function option_passed() {
  # Check if option was passed to a script and return:
  #   1). `0` - option not passed
  #   2). `1` - option passed
  #   3). `neither 0 nor 1` - option was passed but assume we probably need its value e.g.:
  #       a). `--retries=2` will return `2` while `--test='--create-db -vv'` will return `--create-db -vv`
  #
  # N/B: By default (1) and (2) will do a strict equality check whereas (3) won't. Therefore, in order to get
  # the expected output (return value), you need to proved either of the following as a second option to this
  # function:
  #   1). `--require-value` - do a lazy check but MAKE SURE an option is accompanied by a value if passed.
  #   2). `--contains` - do a lazy check for an option's value but don't report an error if non was passed.

  error_msg="'$1' option requires a value passed in the format ${1}='<value>'"
  for option in "${script_options[@]}"; do
    if [ "${2:-}" == "--require-value" ] || [ "${2:-}" == "--contains" ]; then
      if [[ "$option" == *"$1"* ]]; then
        res=1
        if [[ "$option" == *"="* ]]; then
          res=$(echo "$option" | cut -d'=' -f 2)
          if [ -z "$res" ]; then
            res=1
            if [ "${2:-}" == "--require-value" ]; then
              echo >&2 "$error_msg"
              exit 1
            fi
          fi
        elif [ "${2:-}" == "--require-value" ]; then
          echo >&2 "$error_msg"
          exit 1
        fi
        # else assume the options is used as a flag
        (echo "$res")
        return 0
      fi
    elif [ "$1" == "$option" ]; then
      (echo 1)
      return 0
    fi
  done
  (echo 0)
}

# Color codes https://en.wikipedia.org/wiki/ANSI_escape_code
DANGER='\033[0;31m'
SUCCESS='\033[0;32m'
WARNING='\033[0;33m'
NEUTRAL='\e[0m'

function echo_colored() {
  if [ "$(option_passed --no-color)" -eq 0 ] && [ "${COLOR:-1}" -eq 1 ]; then
    color="${2:-}"
    if [ -z "$color" ]; then
      echo -e "${WARNING}Useless 'echo_colored' - color not specified!$NEUTRAL"
      (echo "$1")
    else
      (echo -e "${color}${1}$NEUTRAL")
    fi
  else
    (echo "$1")
  fi
}

function echo_success() {
  (echo_colored "$1" "$SUCCESS")
}

function echo_error() {
  (echo_colored "$1" "$DANGER")
}

function echo_warning() {
  (echo_colored "$1" "$WARNING")
}

# see https://www.shellscript.sh/exitcodes.html
function check_errors() {
  # Function. Parameter 1 is the return code
  # Para. 2 is text to display on failure.
  if [ "${1}" -ne "0" ]; then
    echo_error "ERROR #${1} : ${2}"
    # as a bonus, make our script exit with the right error code.
    exit "${1}"
  fi
}

function element_in_array() {
  local element_to_lookup="${1:?}"
  for element in "${@:2}"; do
    [[ "$element" == "$element_to_lookup" ]] && return 0
  done
  return 1
}

retries=$(option_passed --retries --require-value)
if [ -z "$retries" ] || [ "$retries" == "0" ]; then
  retries="${RETRIES:-10}"
fi

timeout=$(option_passed --timeout --require-value) # in seconds
if [ -z "$timeout" ] || [ "$timeout" == "0" ]; then
  timeout="${TIMEOUT:-5}"
fi

backoff_multiplier=$(option_passed --backoff --require-value)
if [ -z "$backoff_multiplier" ] || [ "$backoff_multiplier" == "0" ]; then
  backoff_multiplier="${BACKOFF_MULTIPLIER:-1}"
fi

function run_command_with_retry() {
  local command="$1"
  local retries=$retries
  local timeout=$timeout
  local on_retry_exhausted="${2:-}"

  until /bin/bash -c "$command"; do
    if [ "$retries" == "0" ]; then
      echo -e "Error running <${DANGER}$command $NEUTRAL>!" >&2
      if [ -z "$on_retry_exhausted" ]; then
        exit 1
      fi
      /bin/bash -c "$on_retry_exhausted"
      break
    else
      echo -e "Rerunning <${WARNING}$command $NEUTRAL> in ${timeout} seconds; $retries attempt$(if [ "$retries" -ne 1 ]; then echo s; fi) remaining..."
      sleep "${timeout}s"
      timeout=$((timeout + (timeout * backoff_multiplier)))
      retries=$((retries - 1))
    fi
  done
}
