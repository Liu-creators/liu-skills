#!/usr/bin/env bash
# Create a reminder in Apple Reminders via AppleScript.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

NAME=""
LIST_NAME=""
NOTES=""
DUE_DATE=""
SET_DUE=0
SET_URGENT=0
SET_FLAGGED=0

usage() {
  cat <<'EOF'
Usage: create-reminder.sh --name TITLE [options]

Required:
  --name TITLE       Reminder title

Options:
  --list NAME        Target list (default: first list in Reminders)
  --notes TEXT       Notes / body text
  --due-date DATE    Due date as YYYY-MM-DD
  --urgent           Mark as urgent / high priority
  --flag             Add flag
  -h, --help         Show this help

Examples:
  create-reminder.sh --name "买牛奶" --list 提醒
  create-reminder.sh --name "周报" --list 任务 --due-date 2026-06-25 --notes "周五前提交"
  create-reminder.sh --name "Python 工程化" --urgent --flag
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2 ;;
    --list) LIST_NAME="${2:-}"; shift 2 ;;
    --notes) NOTES="${2:-}"; shift 2 ;;
    --due-date) DUE_DATE="${2:-}"; SET_DUE=1; shift 2 ;;
    --urgent) SET_URGENT=1; shift ;;
    --flag) SET_FLAGGED=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Error: --name is required." >&2
  usage >&2
  exit 1
fi

if [[ $SET_DUE -eq 1 ]]; then
  parse_due_date "$DUE_DATE"
else
  export DUE_YEAR="" DUE_MONTH="" DUE_DAY=""
fi

check_macos
export_b64 REMINDER_NAME "$NAME"
export_b64 REMINDER_LIST "$LIST_NAME"
export_b64 REMINDER_NOTES "$NOTES"
export SET_DUE SET_URGENT SET_FLAGGED

osascript <<APPLESCRIPT
$(applescript_decode_b64)

set reminderName to my decodeEnv("REMINDER_NAME_B64")
set listName to my decodeEnv("REMINDER_LIST_B64")
set reminderNotes to my decodeEnv("REMINDER_NOTES_B64")
set setDue to (system attribute "SET_DUE") is "1"
set setUrgent to (system attribute "SET_URGENT") is "1"
set setFlagged to (system attribute "SET_FLAGGED") is "1"

tell application "Reminders"
  if listName is "" then
    if (count of lists) is 0 then error "No reminder lists found."
    set targetList to first list
  else
    set targetList to missing value
    repeat with reminderList in lists
      if name of reminderList is listName then
        set targetList to reminderList
        exit repeat
      end if
    end repeat
    if targetList is missing value then error "List not found: " & listName
  end if

  set props to {name:reminderName}
  if reminderNotes is not "" then set props to props & {body:reminderNotes}

  set newReminder to make new reminder at end of reminders of targetList with properties props

  if setDue then
    set y to (system attribute "DUE_YEAR") as integer
    set m to (system attribute "DUE_MONTH") as integer
    set d to (system attribute "DUE_DAY") as integer
    set dueValue to current date
    set year of dueValue to y
    set month of dueValue to m
    set day of dueValue to d
    set time of dueValue to 9 * hours
    set due date of newReminder to dueValue
  end if

  if setUrgent then set priority of newReminder to 1
  if setFlagged then set flagged of newReminder to true

  set output to "已创建提醒: " & reminderName & linefeed & "列表: " & (name of targetList)
  if setDue then
    set output to output & linefeed & "截止: " & (system attribute "DUE_YEAR") & "-" & (system attribute "DUE_MONTH") & "-" & (system attribute "DUE_DAY")
  end if
  if reminderNotes is not "" then set output to output & linefeed & "备注: " & reminderNotes
  if setUrgent then set output to output & linefeed & "紧急: 是"
  if setFlagged then set output to output & linefeed & "旗标: 是"
  return output
end tell
APPLESCRIPT
