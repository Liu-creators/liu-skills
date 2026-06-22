---
name: apple-reminders
description: >-
  Manage Apple Reminders (提醒事项/待办) on macOS: list, create, and update
  tasks via shell scripts. Use when the user asks about reminders, todos, 待办,
  提醒事项, Apple Reminders, creating a reminder, or marking tasks complete.
---

# Apple Reminders

Manage the user's Apple Reminders app on macOS via bundled scripts. **macOS only.**

## Rules

1. Always run the appropriate script — do not guess reminder content or claim success without script output.
2. Before **update**, if the match might be ambiguous, run `list-reminders.sh --search` first.
3. If `update-reminder.sh` reports multiple matches, retry with `--list` or a more specific `--search`.

Script root: `~/.cursor/skills/apple-reminders/scripts/`

## Query

```bash
bash ~/.cursor/skills/apple-reminders/scripts/list-reminders.sh
```

| Flag | Purpose |
|------|---------|
| `--list NAME` | Filter to one list |
| `--search TEXT` | Title contains TEXT |
| `--with-due-date` | Show due dates |
| `--all` | Include completed |

## Create

```bash
bash ~/.cursor/skills/apple-reminders/scripts/create-reminder.sh \
  --name "标题" \
  [--list 列表名] \
  [--notes "备注"] \
  [--due-date YYYY-MM-DD]
```

- `--name` is required.
- Without `--list`, uses the first list in Reminders.

```bash
# Examples
bash ~/.cursor/skills/apple-reminders/scripts/create-reminder.sh --name "买牛奶" --list 提醒
bash ~/.cursor/skills/apple-reminders/scripts/create-reminder.sh \
  --name "周报" --list 任务 --due-date 2026-06-25 --notes "周五前提交"
```

## Update

```bash
bash ~/.cursor/skills/apple-reminders/scripts/update-reminder.sh \
  --search "关键词" \
  [--list 列表名] \
  [--new-name "新标题"] \
  [--notes "新备注" | --clear-notes] \
  [--due-date YYYY-MM-DD | --clear-due-date] \
  [--complete | --uncomplete] \
  [--move-to 目标列表]
```

- `--search` is required (case-insensitive substring match).
- At least one modification flag is required.
- Only updates **one** reminder; errors if zero or multiple matches.

```bash
# Examples
bash ~/.cursor/skills/apple-reminders/scripts/update-reminder.sh --search "买牛奶" --complete
bash ~/.cursor/skills/apple-reminders/scripts/update-reminder.sh \
  --list 提醒 --search "Agent Skills" --new-name "Agent Skills 进阶"
bash ~/.cursor/skills/apple-reminders/scripts/update-reminder.sh \
  --search "周报" --due-date 2026-06-30 --notes "延期一周"
```

## Workflow by intent

| User intent | Action |
|-------------|--------|
| 查看 / 有哪些待办 | `list-reminders.sh` |
| 新建 / 添加提醒 | `create-reminder.sh --name ...` |
| 改标题 / 改备注 / 改日期 | `update-reminder.sh --search ...` + flags |
| 完成 / 勾选 | `update-reminder.sh --search ... --complete` |
| 取消完成 | `update-reminder.sh --search ... --uncomplete` |
| 移到另一个列表 | `update-reminder.sh --search ... --move-to ...` |

## Response format

**Query** — group by list:

```markdown
## Apple 提醒事项（未完成）

共 N 条

### 提醒
- Item 1
```

**Create / update** — quote the script's success output and summarize changes in one line.

## Errors

| Symptom | Action |
|---------|--------|
| Permission denied | Grant Terminal/Cursor **Automation → Reminders** in System Settings |
| Not on macOS | Explain macOS-only limitation |
| Multiple matches on update | Show matches from error; retry with `--list` or narrower `--search` |
| List not found | Run `list-reminders.sh` to see list names |

## Out of scope

- Deleting reminders permanently.
- iOS-only or iCloud web access.
