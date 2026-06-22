#!/usr/bin/env bash
# Update an existing reminder in Apple Reminders via AppleScript.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

SEARCH=""
LIST_FILTER=""
NEW_NAME=""
NOTES=""
SET_NOTES=0
DUE_DATE=""
SET_DUE=0
CLEAR_DUE=0
MARK_COMPLETE=0
MARK_INCOMPLETE=0
MOVE_TO=""

usage() {
  cat <<'EOF'
Usage: update-reminder.sh --search TEXT [options]

Required:
  --search TEXT      Match reminders whose title contains TEXT (case-insensitive)

Options:
  --list NAME        Limit search to one list
  --new-name TITLE   Rename the reminder
  --notes TEXT       Replace notes / body (use --clear-notes to remove)
  --clear-notes      Remove notes
  --due-date DATE    Set due date as YYYY-MM-DD
  --clear-due-date   Remove due date
  --complete         Mark as completed
  --uncomplete       Mark as incomplete
  --move-to LIST     Move reminder to another list
  -h, --help         Show this help

At least one modification flag is required.

Examples:
  update-reminder.sh --search "买牛奶" --complete
  update-reminder.sh --search "Agent Skills" --new-name "Agent Skills 进阶"
  update-reminder.sh --list 任务 --search "周报" --due-date 2026-06-30
  update-reminder.sh --search "旧任务" --move-to 提醒 --notes "已迁移"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --search) SEARCH="${2:-}"; shift 2 ;;
    --list) LIST_FILTER="${2:-}"; shift 2 ;;
    --new-name) NEW_NAME="${2:-}"; shift 2 ;;
    --notes) NOTES="${2:-}"; SET_NOTES=1; shift 2 ;;
    --clear-notes) SET_NOTES=1; NOTES=""; shift ;;
    --due-date) DUE_DATE="${2:-}"; SET_DUE=1; shift 2 ;;
    --clear-due-date) CLEAR_DUE=1; shift ;;
    --complete) MARK_COMPLETE=1; shift ;;
    --uncomplete) MARK_INCOMPLETE=1; shift ;;
    --move-to) MOVE_TO="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$SEARCH" ]]; then
  echo "Error: --search is required." >&2
  usage >&2
  exit 1
fi

if [[ $SET_DUE -eq 1 && $CLEAR_DUE -eq 1 ]]; then
  echo "Error: --due-date and --clear-due-date cannot be used together." >&2
  exit 1
fi

if [[ $MARK_COMPLETE -eq 1 && $MARK_INCOMPLETE -eq 1 ]]; then
  echo "Error: --complete and --uncomplete cannot be used together." >&2
  exit 1
fi

if [[ -z "$NEW_NAME" && $SET_NOTES -eq 0 && $SET_DUE -eq 0 && $CLEAR_DUE -eq 0 \
  && $MARK_COMPLETE -eq 0 && $MARK_INCOMPLETE -eq 0 && -z "$MOVE_TO" ]]; then
  echo "Error: specify at least one modification (--new-name, --notes, --due-date, --clear-due-date, --complete, --uncomplete, --move-to)." >&2
  exit 1
fi

if [[ $SET_DUE -eq 1 ]]; then
  parse_due_date "$DUE_DATE"
else
  export DUE_YEAR="" DUE_MONTH="" DUE_DAY=""
fi

check_macos
export_b64 REMINDER_SEARCH "$SEARCH"
export_b64 REMINDER_LIST_FILTER "$LIST_FILTER"

MATCHES="$(
  osascript <<APPLESCRIPT
$(applescript_decode_b64)

on containsText(haystack, needle)
  if needle is "" then return false
  ignoring case
    return haystack contains needle
  end ignoring
end containsText

set searchText to my decodeEnv("REMINDER_SEARCH_B64")
set listFilter to my decodeEnv("REMINDER_LIST_FILTER_B64")
set resultText to ""

tell application "Reminders"
  repeat with reminderList in lists
    set ln to (name of reminderList) as text
    if listFilter is "" or ln is listFilter then
      repeat with r in (every reminder in reminderList)
        set rName to (name of r) as text
        if my containsText(rName, searchText) then
          set resultText to resultText & ln & "|||" & rName & linefeed
        end if
      end repeat
    end if
  end repeat
end tell

return resultText
APPLESCRIPT
)"

if [[ -z "${MATCHES//[$'\t\r\n ']}" ]]; then
  echo "Error: No reminder matched: $SEARCH" >&2
  exit 1
fi

MATCH_LINES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && MATCH_LINES+=("$line")
done <<< "$MATCHES"

if [[ ${#MATCH_LINES[@]} -gt 1 ]]; then
  echo "Error: Multiple reminders matched (${#MATCH_LINES[@]}). Narrow with --list or a more specific --search:" >&2
  for entry in "${MATCH_LINES[@]}"; do
    list_name="${entry%%|||*}"
    reminder_name="${entry#*|||}"
    echo "  - [$list_name] $reminder_name" >&2
  done
  exit 1
fi

TARGET_LIST="${MATCH_LINES[0]%%|||*}"
TARGET_NAME="${MATCH_LINES[0]#*|||}"
TARGET_LIST="$(printf '%s' "$TARGET_LIST" | tr -d '\r\n')"
TARGET_NAME="$(printf '%s' "$TARGET_NAME" | tr -d '\r\n')"

: "${APPLE_REMINDERS_DEBUG:=}"
if [[ -n "$APPLE_REMINDERS_DEBUG" ]]; then
  echo "DEBUG search=[$SEARCH] matches=[$MATCHES] target=[$TARGET_LIST|||$TARGET_NAME]" >&2
fi

export_b64 TARGET_LIST "$TARGET_LIST"
export_b64 TARGET_NAME "$TARGET_NAME"
export_b64 REMINDER_NEW_NAME "$NEW_NAME"
export_b64 REMINDER_NOTES "$NOTES"
export_b64 REMINDER_MOVE_TO "$MOVE_TO"
export SET_NOTES SET_DUE CLEAR_DUE MARK_COMPLETE MARK_INCOMPLETE

osascript <<APPLESCRIPT
$(applescript_decode_b64)

set targetListName to my decodeEnv("TARGET_LIST_B64")
set targetReminderName to my decodeEnv("TARGET_NAME_B64")
set newName to my decodeEnv("REMINDER_NEW_NAME_B64")
set newNotes to my decodeEnv("REMINDER_NOTES_B64")
set moveToList to my decodeEnv("REMINDER_MOVE_TO_B64")
set setNotes to (system attribute "SET_NOTES") is "1"
set setDue to (system attribute "SET_DUE") is "1"
set clearDue to (system attribute "CLEAR_DUE") is "1"
set markComplete to (system attribute "MARK_COMPLETE") is "1"
set markIncomplete to (system attribute "MARK_INCOMPLETE") is "1"
set oldName to targetReminderName
set oldList to targetListName

tell application "Reminders"
  set targetList to missing value
  repeat with reminderList in lists
    if (name of reminderList as text) is targetListName then
      set targetList to reminderList
      exit repeat
    end if
  end repeat
  if targetList is missing value then error "List not found: " & targetListName

  tell targetList
    set matches to (every reminder whose name is targetReminderName)
    if (count of matches) is 0 then error "Reminder not found: " & targetReminderName
    if (count of matches) > 1 then error "Multiple reminders share the same title in this list: " & targetReminderName
    set r to item 1 of matches
  end tell

  set changes to {}

  if newName is not "" then
    set name of r to newName
    set end of changes to "标题: " & oldName & " → " & newName
  end if

  if setNotes then
    if newNotes is "" then
      set body of r to ""
      set end of changes to "备注: 已清除"
    else
      set body of r to newNotes
      set end of changes to "备注: 已更新"
    end if
  end if

  if setDue then
    set y to (system attribute "DUE_YEAR") as integer
    set m to (system attribute "DUE_MONTH") as integer
    set d to (system attribute "DUE_DAY") as integer
    set dueValue to current date
    set year of dueValue to y
    set month of dueValue to m
    set day of dueValue to d
    set time of dueValue to 9 * hours
    set due date of r to dueValue
    set end of changes to "截止: " & (system attribute "DUE_YEAR") & "-" & (system attribute "DUE_MONTH") & "-" & (system attribute "DUE_DAY")
  end if

  if clearDue then
    try
      set due date of r to missing value
    on error
      tell r to set due date to missing value
    end try
    set end of changes to "截止: 已清除"
  end if

  if markComplete then
    set completed of r to true
    set completion date of r to current date
    set end of changes to "状态: 已完成"
  end if

  if markIncomplete then
    set completed of r to false
    set end of changes to "状态: 未完成"
  end if

  if moveToList is not "" then
    set destList to missing value
    repeat with reminderList in lists
      if (name of reminderList as text) is moveToList then
        set destList to reminderList
        exit repeat
      end if
    end repeat
    if destList is missing value then error "Target list not found: " & moveToList
    move r to destList
    set end of changes to "列表: " & oldList & " → " & moveToList
  end if

  set finalName to (name of r) as text
  set output to "已更新提醒: " & finalName & linefeed & "列表: "
  if moveToList is not "" then
    set output to output & moveToList
  else
    set output to output & oldList
  end if
  repeat with c in changes
    set output to output & linefeed & c
  end repeat
  return output
end tell
APPLESCRIPT
