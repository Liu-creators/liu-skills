#!/usr/bin/env bash
# Query incomplete (or all) reminders from Apple Reminders via AppleScript.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

INCLUDE_COMPLETED=0
LIST_FILTER=""
SEARCH_TEXT=""
WITH_DUE_DATE=0

usage() {
  cat <<'EOF'
Usage: list-reminders.sh [options]

Options:
  --all              Include completed reminders (default: incomplete only)
  --list NAME        Filter to a single list name
  --search TEXT      Filter reminders whose title contains TEXT (case-insensitive)
  --with-due-date    Include due date column (slower)
  -h, --help         Show this help

Examples:
  list-reminders.sh
  list-reminders.sh --list 任务
  list-reminders.sh --search Leetcode
  list-reminders.sh --with-due-date
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) INCLUDE_COMPLETED=1; shift ;;
    --list) LIST_FILTER="${2:-}"; shift 2 ;;
    --search) SEARCH_TEXT="${2:-}"; shift 2 ;;
    --with-due-date) WITH_DUE_DATE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

check_macos
export_b64 LIST_FILTER "$LIST_FILTER"
export_b64 SEARCH_TEXT "$SEARCH_TEXT"
export INCLUDE_COMPLETED WITH_DUE_DATE

osascript <<APPLESCRIPT
$(applescript_decode_b64)

on containsText(haystack, needle)
  if needle is "" then return true
  ignoring case
    return haystack contains needle
  end ignoring
end containsText

on formatDueDate(d)
  if d is missing value then return "—"
  set y to year of d as integer
  set m to month of d as integer
  set dy to day of d as integer
  return (y as text) & "-" & text -2 thru -1 of ("0" & (m as text)) & "-" & text -2 thru -1 of ("0" & (dy as text))
end formatDueDate

set includeCompleted to (system attribute "INCLUDE_COMPLETED") is "1"
set listFilter to my decodeEnv("LIST_FILTER_B64")
set searchText to my decodeEnv("SEARCH_TEXT_B64")
set withDueDate to (system attribute "WITH_DUE_DATE") is "1"

tell application "Reminders"
  set output to ""
  set totalCount to 0

  repeat with reminderList in lists
    set listName to name of reminderList
    if listFilter is not "" and listName is not listFilter then
      -- skip
    else
      set itemsInList to {}
      repeat with r in (every reminder in reminderList)
        set completedFlag to completed of r
        if includeCompleted or (completedFlag is false) then
          set rName to name of r
          if my containsText(rName, searchText) then
            set end of itemsInList to r
          end if
        end if
      end repeat

      if (count of itemsInList) > 0 then
        set output to output & "【" & listName & "】" & linefeed
        repeat with r in itemsInList
          set rName to name of r
          set itemText to "  - " & rName
          if withDueDate then
            try
              set d to due date of r
              set itemText to itemText & "  （截止: " & my formatDueDate(d) & "）"
            on error
              set itemText to itemText & "  （截止: —）"
            end try
          end if
          if includeCompleted and (completed of r) then
            set itemText to itemText & "  [已完成]"
          end if
          set output to output & itemText & linefeed
          set totalCount to totalCount + 1
        end repeat
        set output to output & linefeed
      end if
    end if
  end repeat

  if totalCount is 0 then
    if includeCompleted then
      return "（无提醒事项）"
  else
      return "（无未完成提醒）"
    end if
  end if

  set summary to "共 " & totalCount & " 条"
  if includeCompleted then
    set summary to summary & "提醒"
  else
    set summary to summary & "未完成提醒"
  end if
  return summary & linefeed & linefeed & output
end tell
APPLESCRIPT
