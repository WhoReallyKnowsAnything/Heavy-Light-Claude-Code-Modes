#!/bin/bash
# Claude Code Plugin Toggle Script
# Switches between "light" (simple edits) and "heavy" (full reviews) modes

SETTINGS_FILE="$HOME/.claude/settings.json"
TEMP_FILE="/tmp/settings-claude-$$.json"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "❌ Settings file not found: $SETTINGS_FILE"
  exit 1
fi

# Backup before changes
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup" 2>/dev/null

MODE="$1"

case "$MODE" in
  light)
    echo "🔄 Switching to LIGHT mode (minimal plugins for small edits)..."

    # Use jq to modify enabledPlugins - disable heavy plugins
    jq '
      .enabledPlugins."everything-claude-code@everything-claude-code" = false |
      .enabledPlugins."example-skills@anthropic-agent-skills" = false |
      .enabledPlugins."agent-sdk-dev@claude-plugins-official" = false |
      .enabledPlugins."claude-code-setup@claude-plugins-official" = false |
      .enabledPlugins."claude-md-management@claude-plugins-official" = false |
      .enabledPlugins."code-review@claude-plugins-official" = false |
      .enabledPlugins."code-simplifier@claude-plugins-official" = false |
      .enabledPlugins."commit-commands@claude-plugins-official" = false |
      .enabledPlugins."feature-dev@claude-plugins-official" = false |
      .enabledPlugins."frontend-design@claude-plugins-official" = false |
      .enabledPlugins."hookify@claude-plugins-official" = false |
      .enabledPlugins."pr-review-toolkit@claude-plugins-official" = false |
      .enabledPlugins."security-guidance@claude-plugins-official" = false |
      .enabledPlugins."skill-creator@claude-plugins-official" = false |
      .enabledPlugins."gitlab@claude-plugins-official" = false |
      .enabledPlugins."slack@claude-plugins-official" = false |
      .enabledPlugins."linear@claude-plugins-official" = false |
      .enabledPlugins."playwright@claude-plugins-official" = false |
      .enabledPlugins."stripe@claude-plugins-official" = false |
      .enabledPlugins."supabase@claude-plugins-official" = false |
      .enabledPlugins."firebase@claude-plugins-official" = false |
      .enabledPlugins."asana@claude-plugins-official" = false |
      .enabledPlugins."greptile@claude-plugins-official" = false |
      .enabledPlugins."context7@claude-plugins-official" = false |
      .enabledPlugins."laravel-boost@claude-plugins-official" = false |
      .enabledPlugins."serena@claude-plugins-official" = false
    ' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"

    echo "✅ Light mode enabled"
    echo "   Kept: LSPs (typescript, python, etc.), GitHub, superpowers"
    echo "   Disabled: Everything Claude Code, all review agents, integrations"
    echo ""
    echo "💡 Tip: Use /code-foundations:hack for simple edits"
    echo "💡 Tip: Toggle extended thinking OFF (Cmd/Ctrl+T) for small changes"
    ;;

  heavy)
    echo "🔄 Switching to HEAVY mode (full plugin set for complex reviews)..."

    # Re-enable all plugins
    jq '
      .enabledPlugins."everything-claude-code@everything-claude-code" = true |
      .enabledPlugins."example-skills@anthropic-agent-skills" = true |
      .enabledPlugins."agent-sdk-dev@claude-plugins-official" = true |
      .enabledPlugins."claude-code-setup@claude-plugins-official" = true |
      .enabledPlugins."claude-md-management@claude-plugins-official" = true |
      .enabledPlugins."code-review@claude-plugins-official" = true |
      .enabledPlugins."code-simplifier@claude-plugins-official" = true |
      .enabledPlugins."commit-commands@claude-plugins-official" = true |
      .enabledPlugins."feature-dev@claude-plugins-official" = true |
      .enabledPlugins."frontend-design@claude-plugins-official" = true |
      .enabledPlugins."hookify@claude-plugins-official" = true |
      .enabledPlugins."pr-review-toolkit@claude-plugins-official" = true |
      .enabledPlugins."security-guidance@claude-plugins-official" = true |
      .enabledPlugins."skill-creator@claude-plugins-official" = true |
      .enabledPlugins."gitlab@claude-plugins-official" = true |
      .enabledPlugins."slack@claude-plugins-official" = true |
      .enabledPlugins."linear@claude-plugins-official" = true |
      .enabledPlugins."playwright@claude-plugins-official" = true |
      .enabledPlugins."stripe@claude-plugins-official" = true |
      .enabledPlugins."supabase@claude-plugins-official" = true |
      .enabledPlugins."firebase@claude-plugins-official" = true |
      .enabledPlugins."asana@claude-plugins-official" = true |
      .enabledPlugins."greptile@claude-plugins-official" = true |
      .enabledPlugins."context7@claude-plugins-official" = true |
      .enabledPlugins."laravel-boost@claude-plugins-official" = true |
      .enabledPlugins."serena@claude-plugins-official" = true
    ' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"

    echo "✅ Heavy mode enabled"
    echo "   All plugins active - use for full code reviews and complex features"
    ;;

  *)
    echo "Usage: $0 [light|heavy]"
    echo ""
    echo "  light   - Disables heavy plugins for small edits (~6x less token usage)"
    echo "  heavy   - Re-enables all plugins for full reviews"
    echo ""
    echo "Current mode:"
    ACTIVE_COUNT=$(jq '[.enabledPlugins[] | select(. == true)] | length' "$SETTINGS_FILE" 2>/dev/null || echo "?")
    echo "  Active plugins: $ACTIVE_COUNT/34"
    echo ""
    echo "💡 After switching, restart Claude Code for changes to take effect"
    exit 1
    ;;
esac
