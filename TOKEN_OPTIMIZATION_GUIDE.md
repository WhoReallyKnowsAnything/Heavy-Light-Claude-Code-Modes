# Claude Code Token Optimization Guide

## Problem: Small Edits Cost 3k+ Tokens

You have 34 plugins enabled, including `everything-claude-code` which loads **15 skills with 614 checklist items**. This massive overhead loads ~110k tokens *before* your edit even happens.

## Solutions

### 1. **Switch to Light Mode for Simple Edits**

```bash
# Run in terminal:
~/.claude/switch-mode.sh light

# Then RESTART Claude Code for changes to take effect
```

**Light mode keeps:**
- LSP plugins (TypeScript, Python, Go, etc.) - needed for code intelligence
- GitHub plugin - for PR operations
- `superpowers` - core workflows
- ~7 plugins total

**Light mode disables:**
- `everything-claude-code` - **the biggest offender**
- All review agents (code-review, pr-review-toolkit, feature-dev)
- All writing agents (article-writing, investor-outreach)
- All integration plugins (Slack, Stripe, Notion, etc.)

**Expected savings:** 3k → 300 tokens for simple edits (10x reduction)

---

### 2. **Use `/code-foundations:hack` for Direct Edits**

Instead of `/code-foundations:review` for small changes:

```
# EXPENSIVE (614 checks, multiple agents):
/code-foundations:review "fix typo"

# CHEAP (direct edit, no agents):
/code-foundations:hack "fix typo in README"

# For full reviews, use sanity profile:
/code-foundations:review --profile light  # 99 checks instead of 614
```

---

### 3. **Toggle Extended Thinking**

**Keyboard shortcut:** `Cmd/Ctrl + T`

- **ON (default):** Deep reasoning, ~3-5x token usage
- **OFF:** Direct responses, minimal tokens

**Rule:**
- Complex architecture/debugging → **ON**
- Simple edits, typos, refactoring → **OFF**

---

### 4. **Custom Light Profile for Code Review**

You already have this file: `~/.claude/.code-foundations/profiles/light.yaml`

```yaml
name: light
description: "Minimal checks for small edits"
max_parallelism: 1
models:
  checking: haiku      # 3x cheaper than sonnet
  investigation: haiku
checklists:
  - path: agents/profiles/sanity.yaml  # 99 checks, not 614
```

**Usage:**
```
/code-foundations:review --profile light
```

---

## Recommended Workflow

### **For small edits (typos, one-line changes):**
1. `~/.claude/switch-mode.sh light`
2. Restart Claude Code
3. `Cmd/Ctrl+T` to disable extended thinking
4. `/code-foundations:hack "describe change"` or just edit directly
5. **Token cost:** ~100-500 tokens

### **For medium changes (few files, simple feature):**
1. `~/.claude/switch-mode.sh heavy`
2. Restart Claude Code
3. `Cmd/Ctrl+T` (keep off unless complex)
4. `/code-foundations:review --profile light`
5. **Token cost:** ~1-3k tokens

### **For major changes/PR reviews:**
1. `~/.claude/switch-mode.sh heavy`
2. Restart Claude Code
3. `Cmd/Ctrl+T` (enable for complex issues)
4. `/code-foundations:review --pr` (or `--profile pr`)
5. **Token cost:** ~10-50k tokens (but justified for complexity)

---

## Quick Reference: Token Costs

| Operation | Heavy Mode | Light Mode |
|-----------|-----------|------------|
| Simple edit (1 file) | 3-5k tokens | 200-500 tokens |
| Code review (5 files) | 20-50k tokens | 2-5k tokens |
| Full PR (614 checks) | 100-200k tokens | N/A (use medium) |

---

## Files Created

1. **`~/.claude/.code-foundations/profiles/light.yaml`**
   - Minimal code-foundations profile (99 checks, haiku models)

2. **`~/.claude/switch-mode.sh`**
   - Toggle between light/heavy plugin sets
   - Usage: `~/.claude/switch-mode.sh [light|heavy]`

3. **`~/.claude/TOKEN_OPTIMIZATION_GUIDE.md`** (this file)
   - Documentation and usage examples

---

## Manual Plugin Control

If you want to manually edit which plugins are active:

```bash
# Edit settings.json
vim ~/.claude/settings.json

# Manually set specific plugins to true/false:
{
  "enabledPlugins": {
    "everything-claude-code@everything-claude-code": false,  // Disable for light mode
    "code-review@claude-plugins-official": false,
    // ... etc
  }
}
```

**After any manual change:** Restart Claude Code completely.

---

## Monitoring Your Usage

```bash
# Check current plugin count
grep -c '"enabledPlugins":' ~/.claude/settings.json

# View active plugins
jq '.enabledPlugins | keys[]' ~/.claude/settings.json

# See recent token usage (billing)
claude code --billing
```

---

## Troubleshooting

**Q: Changes don't seem to take effect**
A: Claude Code caches plugin state. **Restart completely** (quit and reopen).

**Q: I need a plugin that's disabled in light mode**
A: Run `~/.claude/switch-mode.sh heavy`, restart, then use it.

**Q: Auto code review still runs on every edit**
A: There's no setting for this yet. Workaround: Use `light` mode, or use `/code-foundations:hack` instead of letting auto-triggers fire.

**Q: My LSP (TypeScript/Python) isn't working in light mode**
A: It should be - LSPs are kept in light mode. If not, check `switch-mode.sh` line 27-35 to ensure your language LSP is listed as `true`.

---

## Notes on pluginProfiles

The `pluginProfiles` feature exists in the **schema** but is **not yet implemented** in Claude Code (as of March 2026). The `switch-mode.sh` script is a workaround until that feature is live.

---

## Questions?

Check the docs:
- `~/.claude/CLAUDE.md` - Your local code-foundations docs
- `~/.claude/PLUGINS.md` - Plugin documentation
- `/help` in Claude Code
