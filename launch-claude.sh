#!/usr/bin/env bash
# launch-claude.sh
# -------------------------------------------------
# 1) Choose the working directory:
#    - Home (~)
#    - Current directory (pwd)
#    - Custom path (entered by you)
# 2) Choose the mode: Light (minimal plugins) or Heavy (full features)
# 3) Choose the model source:
#    - Claude      - default model
#    - Claude      - pick a model name
#    - OpenRouter  - default model
#    - OpenRouter  - pick a model name
# 4) Choose the conversation:
#    - New conversation
#    - Existing conversation (pick from a list)
# 5) Select free OpenRouter model for lightweight second session
# 6) Open both sessions in new terminal windows.
# -------------------------------------------------

# Use explicit python3 path (Anaconda) for OpenRouter API calls
PYTHON_CMD="/opt/anaconda3/bin/python3"
if [[ ! -x "$PYTHON_CMD" ]]; then
    # Fallback to system python3
    PYTHON_CMD=$(which python3 2>/dev/null || echo "python3")
fi

# ---------- 1) Mode selection ----------
echo "Select Claude Code mode:"
echo "  1) Light mode   - Minimal plugins (ideal for simple edits, ~10x token savings)"
echo "  2) Heavy mode   - All plugins enabled (for full code reviews)"
read -rp "Enter 1-2 [default: 2]: " mode_choice
MODE_CHOICE="${mode_choice:-2}"

case "$MODE_CHOICE" in
    1)
        echo "🔄 Applying LIGHT mode settings..."
        ~/.claude/switch-mode.sh light
        MODE_LABEL="Light"
        ;;
    2)
        echo "🔄 Using HEAVY mode settings..."
        ~/.claude/switch-mode.sh heavy
        MODE_LABEL="Heavy"
        ;;
    *)
        echo "Invalid choice - using Heavy mode."
        ~/.claude/switch-mode.sh heavy
        MODE_LABEL="Heavy"
        ;;
esac

# Secondary session policy
echo "   Main session:   $MODE_LABEL mode"

# Decide whether to auto-launch free session
if [[ "$MODE_CHOICE" == "1" ]]; then
    # Light mode - both can be light (no conflict)
    LAUNCH_FREE="yes"
    FREE_MODE_DESC="LIGHT (same as main)"
else
    # Heavy mode - ask user
    echo "Select secondary (free) session behavior:"
    echo "  1) Launch in HEAVY mode ($MODE_LABEL) - simple, but both use heavy plugins"
    echo "  2) Launch in LIGHT mode - requires temporary settings switch, but free session is light"
    read -rp "Enter 1-2 [default: 1]: " free_mode_choice
    FREE_MODE_CHOICE="${free_mode_choice:-1}"

    if [[ "$FREE_MODE_CHOICE" == "2" ]]; then
        LAUNCH_FREE="light"
        FREE_MODE_DESC="LIGHT (temporary switch)"
    else
        LAUNCH_FREE="heavy"
        FREE_MODE_DESC="HEAVY (same as main)"
    fi
fi

read -rp "Press Enter to continue launching... " </dev/tty

# ---------- 2) Directory selection ----------
echo ""
echo "Select a directory for Claude Code:"
echo "  1) Home (~)"
echo "  2) Current directory ($(pwd))"
echo "  3) Custom path"
read -rp "Enter 1-3: " dir_choice

case "$dir_choice" in
    1) TARGET_DIR="$HOME" ;;
    2) TARGET_DIR="$(pwd)" ;;
    3)
        read -rp "Enter the full path you want to use: " custom_path
        if [[ -d "$custom_path" ]]; then
            TARGET_DIR="$custom_path"
        else
            echo "Path does not exist - falling back to current directory."
            TARGET_DIR="$(pwd)"
        fi
        ;;
    *)  echo "Invalid choice - using current directory."
        TARGET_DIR="$(pwd)" ;;
esac

# ---------- 2) Model selection ----------
echo ""
echo "Choose a model source:"
echo "  1) Claude         - default model"
echo "  2) Claude         - specify a model"
echo "  3) OpenRouter     - default model"
echo "  4) OpenRouter     - specify a model"
read -rp "Enter 1-4: " model_choice

MODEL_TYPE=""
MODEL_NAME=""
DISPLAY_NAME=""
env_part=""

case "$model_choice" in
    1)
        MODEL_TYPE="claude"
        MODEL_NAME="default"
        DISPLAY_NAME="Claude Default"
        ;;
    2)
        MODEL_TYPE="claude"
        read -rp "Enter Claude model name (e.g. claude-sonnet-4-6): " MODEL_NAME
        DISPLAY_NAME="$MODEL_NAME"
        ;;
    3)
        MODEL_TYPE="openrouter"
        MODEL_NAME="default"
        DISPLAY_NAME="OpenRouter Default"
        OR_KEY="${OPENROUTER_API_KEY:-}"
        if [[ -z "$OR_KEY" ]]; then
            read -rp "Enter your OpenRouter API key: " OR_KEY
        fi
        env_part="ANTHROPIC_BASE_URL=https://openrouter.ai/api ANTHROPIC_AUTH_TOKEN=$OR_KEY ANTHROPIC_API_KEY=''"
        ;;
    4)
        MODEL_TYPE="openrouter"
        read -rp "Enter OpenRouter model name (e.g. anthropic/claude-opus-4): " MODEL_NAME
        DISPLAY_NAME="$MODEL_NAME"
        OR_KEY="${OPENROUTER_API_KEY:-}"
        if [[ -z "$OR_KEY" ]]; then
            read -rp "Enter your OpenRouter API key: " OR_KEY
        fi
        env_part="ANTHROPIC_BASE_URL=https://openrouter.ai/api ANTHROPIC_AUTH_TOKEN=$OR_KEY ANTHROPIC_API_KEY=''"
        ;;
    *)
        echo "Invalid choice - using Claude default."
        MODEL_TYPE="claude"
        MODEL_NAME="default"
        DISPLAY_NAME="Claude Default"
        ;;
esac

# ---------- 3) Conversation selection ----------
echo ""
echo "Conversation mode:"
echo "  1) New conversation"
echo "  2) Reuse an existing conversation"
read -rp "Enter 1-2: " conv_choice

CONV_ARG=""
if [[ "$conv_choice" == "2" ]]; then
    echo ""
    echo "Fetching recent sessions..."
    session_lines=()
    while IFS= read -r line; do
        session_lines+=("$line")
    done < <(claude --resume 2>&1 | head -n 20)
    if (( ${#session_lines[@]} )); then
        for line in "${session_lines[@]}"; do
            echo "  $line"
        done
    fi
    read -rp "Enter the session ID to resume (or press Enter for most recent): " session_id
    if [[ -n "$session_id" ]]; then
        CONV_ARG="--resume $session_id"
    else
        CONV_ARG="--resume"
    fi
fi

# ---------- 4) Pick the best free OpenRouter model for the second session ----------
FREE_OR_KEY="${OPENROUTER_API_KEY:-}"
if [[ -z "$FREE_OR_KEY" ]]; then
    read -rp "Enter your OpenRouter API key (needed for free second session): " FREE_OR_KEY
fi
if [[ -z "$FREE_OR_KEY" ]]; then
    echo "⚠️  No OpenRouter API key provided."
    echo "   Free session will be skipped."
    echo "   Set OPENROUTER_API_KEY env var or provide key when prompted."
    FREE_SESSION="skip"
fi

echo ""
echo "Fetching free OpenRouter models..."

# Fetch free models JSON
FREE_MODELS_RESPONSE=$(curl -s https://openrouter.ai/api/v1/models)
if [[ -z "$FREE_MODELS_RESPONSE" ]]; then
    echo "⚠️  Failed to fetch models from OpenRouter API."
    echo "   Free session will be skipped."
    FREE_SESSION="skip"
else
    # Parse and display free models with context length
    FREE_MODEL_LIST=()
    while IFS= read -r line; do
        FREE_MODEL_LIST+=("$line")
    done < <(echo "$FREE_MODELS_RESPONSE" | $PYTHON_CMD -c "
import json, sys
data = json.load(sys.stdin)
models = []
for m in data.get('data', []):
    mid = m.get('id', '')
    if not mid.endswith(':free'):
        continue
    pricing = m.get('pricing', {})
    try:
        prompt = float(pricing.get('prompt', '1'))
        completion = float(pricing.get('completion', '1'))
    except:
        continue
    if not (prompt == 0 and completion == 0):
        continue
    if m.get('deprecated') or m.get('disabled'):
        continue
    models.append({
        'id': mid,
        'name': m.get('name', 'Unknown'),
        'context': m.get('context_length', 0),
        'description': m.get('description', '')[:80]
    })
# Sort by context length descending
models.sort(key=lambda x: x['context'], reverse=True)
for m in models:
    ctx = m['context']
    if ctx >= 1000000:
        ctx_str = f\"{ctx/1000000:.1f}M\"
    elif ctx >= 1000:
        ctx_str = f\"{ctx/1000:.0f}k\"
    else:
        ctx_str = str(ctx)
    print(f\"{m['id']}|{ctx_str}|{m['name']}|{m['description']}\")
")
    TOTAL_FREE=${#FREE_MODEL_LIST[@]}

    if [[ $TOTAL_FREE -eq 0 ]]; then
        echo "⚠️  No free models found."
        echo "   Free session will be skipped."
        FREE_SESSION="skip"
    else
        FREE_SESSION="launch"
        echo ""
        echo "Available free models ($TOTAL_FREE total):"
        echo "  [Context len shown. Weekly limit: N/A - not provided by API]"
        echo ""
        for idx in "${!FREE_MODEL_LIST[@]}"; do
            IFS='|' read -r ID CONTEXT NAME DESC <<< "${FREE_MODEL_LIST[$idx]}"
            printf "  %2d) %-45s | Ctx: %6s | %s\n" "$((idx+1))" "$ID" "$CONTEXT" "$NAME"
        done
        printf "  %2d) Skip free session\n" "$((TOTAL_FREE+1))"
        echo ""
        read -rp "Select model (1-$((TOTAL_FREE+1))): " MODEL_INDEX

        if [[ "$MODEL_INDEX" -lt 1 || "$MODEL_INDEX" -gt $((TOTAL_FREE+1)) ]]; then
            echo "Invalid selection."
            FREE_SESSION="skip"
        elif [[ "$MODEL_INDEX" -eq $((TOTAL_FREE+1)) ]]; then
            echo "Skipping free session."
            FREE_SESSION="skip"
        else
            SELECTED="${FREE_MODEL_LIST[$((MODEL_INDEX-1))]}"
            FREE_MODEL="${SELECTED%%|*}"  # Extract ID before first |
            FREE_DISPLAY=$(echo "$FREE_MODEL" | sed 's/:free$//' | awk -F/ '{print $NF}')
            echo "  Selected: $FREE_DISPLAY"

            # Test the selected model for rate limits
            echo "  Testing rate limit..."
            test_response=$(curl -s https://openrouter.ai/api/v1/chat/completions \
                -H "Authorization: Bearer $FREE_OR_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"model\": \"$FREE_MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"ping\"}], \"max_tokens\": 1}")

            if echo "$test_response" | grep -q '"code":429'; then
                echo "  ⚠️  Selected model is rate-limited right now."
                echo "  Would you like to:"
                echo "    1) Try a different model"
                echo "    2) Use it anyway (may fail)"
                read -rp "  Enter 1-2: " RATE_LIMIT_CHOICE
                if [[ "$RATE_LIMIT_CHOICE" == "1" ]]; then
                    echo "  Please re-run the script to select a different model."
                    FREE_SESSION="skip"
                else
                    echo "  Using rate-limited model (you may experience errors)."
                fi
            else
                echo "  ✓ Model is available (no rate limit detected)"
            fi
        fi
    fi
fi

# ---------- 5) Build the commands ----------
cd_cmd="cd \"$TARGET_DIR\" &&"

case "$MODEL_TYPE" in
    claude)
        if [[ "$MODEL_NAME" == "default" ]]; then
            main_cmd="claude $CONV_ARG"
        else
            main_cmd="claude --model $MODEL_NAME $CONV_ARG"
        fi
        ;;
    openrouter)
        if [[ "$MODEL_NAME" == "default" ]]; then
            main_cmd="claude $CONV_ARG"
        else
            main_cmd="claude --model $MODEL_NAME $CONV_ARG"
        fi
        ;;
esac

CLAUDE_TITLE="Main Session - Claude Code - $DISPLAY_NAME ($MODE_LABEL)"

# ---------- 6) Launch sessions ----------
TMP_CLAUDE=$(mktemp -t claude-session)
chmod +x "$TMP_CLAUDE"

cat > "$TMP_CLAUDE" <<SCRIPT
#!/bin/bash
printf '\033]0;${CLAUDE_TITLE}\007'
$cd_cmd $env_part $main_cmd
rm -- "\$0"
SCRIPT

# Always launch main session
osascript <<APPLESCRIPT_MAIN
tell application "Terminal"
  activate
  do script "bash '$TMP_CLAUDE'"
  delay 0.5
  set current settings of window 1 to settings set "Pro"
  set number of columns of selected tab of window 1 to 110
  set number of rows of selected tab of window 1 to 45
end tell
APPLESCRIPT_MAIN

# Conditionally launch free session with tiling
if [[ "$FREE_SESSION" == "launch" && "$LAUNCH_FREE" != "skip" ]]; then
    echo "🎯 Launching free session with model: $FREE_MODEL"
    TMP_FREE=$(mktemp -t claude-free-session)
    chmod +x "$TMP_FREE"

    if [[ "$MODE_CHOICE" == "2" && "$LAUNCH_FREE" == "light" ]]; then
        FREE_TITLE="Secondary Session - Claude Code - $FREE_DISPLAY (Light)"
        cat > "$TMP_FREE" <<FREESCRIPT
#!/bin/bash
printf '\033]0;${FREE_TITLE}\007'
~/.claude/switch-mode.sh light > /dev/null 2>&1
cd "$TARGET_DIR" && ANTHROPIC_BASE_URL=https://openrouter.ai/api ANTHROPIC_AUTH_TOKEN=$FREE_OR_KEY ANTHROPIC_API_KEY= claude --model $FREE_MODEL
~/.claude/switch-mode.sh heavy > /dev/null 2>&1
rm -- "\$0"
FREESCRIPT
    else
        FREE_TITLE="Secondary Session - Claude Code - $FREE_DISPLAY ($MODE_LABEL)"
        cat > "$TMP_FREE" <<FREESCRIPT
#!/bin/bash
printf '\033]0;${FREE_TITLE}\007'
cd "$TARGET_DIR" && ANTHROPIC_BASE_URL=https://openrouter.ai/api ANTHROPIC_AUTH_TOKEN=$FREE_OR_KEY ANTHROPIC_API_KEY= claude --model $FREE_MODEL
rm -- "\$0"
FREESCRIPT
    fi

    osascript <<EOF
tell application "Terminal"
  delay 0.3
  do script "bash '$TMP_FREE'"
  delay 0.5
  -- Set free window to Clear Dark profile and 150x55 size
  try
    set current settings of window 1 to settings set "Clear Dark"
    set number of columns of selected tab of window 1 to 110
    set number of rows of selected tab of window 1 to 42
  end try
end tell

delay 0.5

-- Position windows side by side without resizing (preserves column/row count)
tell application "System Events"
  tell process "Terminal"
    set frontmost to true
    -- Anchor main session at top-left
    set position of window 2 to {0, 0}
    -- Place free session immediately to the right of main session
    set mainW to item 1 of (size of window 2)
    set position of window 1 to {mainW, 0}
  end tell
end tell
EOF
fi

exit 0
