# Shared helpers for Apple Reminders scripts.

check_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: Apple Reminders is only available on macOS." >&2
    exit 1
  fi
}

export_b64() {
  local var_name="$1"
  local value="$2"
  # shellcheck disable=SC2154
  printf -v "${var_name}_B64" '%s' "$(printf '%s' "$value" | base64 | tr -d '\n')"
  export "${var_name}_B64"
}

parse_due_date() {
  local date_str="$1"
  if [[ "$date_str" =~ ^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$ ]]; then
    export DUE_YEAR="${BASH_REMATCH[1]}"
    export DUE_MONTH="${BASH_REMATCH[2]}"
    export DUE_DAY="${BASH_REMATCH[3]}"
    return 0
  fi
  echo "Error: due date must be YYYY-MM-DD (got: $date_str)" >&2
  return 1
}

applescript_decode_b64() {
  cat <<'APPLESCRIPT'
on decodeB64(encoded)
  if encoded is missing value or encoded is "" then return ""
  return do shell script "printf %s " & quoted form of encoded & " | base64 -D"
end decodeB64

on decodeEnv(varName)
  return my decodeB64(system attribute varName)
end decodeEnv
APPLESCRIPT
}
