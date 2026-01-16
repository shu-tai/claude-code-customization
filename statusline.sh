#!/bin/bash
# Status line script showing Claude usage percentages
# Calls the same API endpoint as /usage

# Read stdin (status line JSON)
STDIN=$(cat)

# Debug: log raw input
echo "$STDIN" > /tmp/statusline_debug.json

# Extract working directory from stdin JSON (relative path only)
CWD=$(/usr/bin/python3 -c "import sys,json,os; d=json.loads('''$STDIN'''); cwd=d.get('workspace',{}).get('current_dir',''); print(os.path.basename(cwd) if cwd else '')" 2>/dev/null)

# Extract model name
MODEL=$(/usr/bin/python3 -c "import json; d=json.loads('''$STDIN'''); print(d.get('model',{}).get('display_name',''))" 2>/dev/null)

# Extract context window tokens (used/available) and remaining percentage
read TOKEN_USED TOKEN_AVAIL TOKEN_REM < <(/usr/bin/python3 -c "
import json
d=json.loads('''$STDIN''')
cw=d.get('context_window',{})
used=cw.get('total_input_tokens',0) + cw.get('total_output_tokens',0)
avail=cw.get('context_window_size',0) or 200000
rem=int(100 * (avail - used) / avail) if avail > 0 else 100
print(f'{used/1000:.1f} {avail//1000}k {rem}')
" 2>/dev/null)

# Colors (using $'...' for ANSI codes)
CB=$'\033[1;34m'  # bold blue for headers (like oh-my-zsh directories)
R=$'\033[0m'

# Color for token display based on remaining
TOKEN_REM=${TOKEN_REM:-100}
if [ "$TOKEN_REM" -gt 50 ]; then
    CT=$'\033[32m'  # green
elif [ "$TOKEN_REM" -gt 20 ]; then
    CT=$'\033[33m'  # yellow
else
    CT=$'\033[31m'  # red
fi

# Get OAuth token from keychain
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [ -z "$CREDS" ]; then
    echo -e "${CWD}  ${CT}${TOKEN_USED}${R}/${TOKEN_AVAIL}  no auth  ${MODEL}"
    exit 0
fi

TOKEN=$(echo "$CREDS" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
    echo -e "${CWD}  ${CT}${TOKEN_USED}${R}/${TOKEN_AVAIL}  no token  ${MODEL}"
    exit 0
fi

# Fetch usage data
USAGE=$(curl -s --max-time 2 \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

if [ -z "$USAGE" ]; then
    echo -e "${CWD}  ${CT}${TOKEN_USED}${R}/${TOKEN_AVAIL}  fetch failed  ${MODEL}"
    exit 0
fi

# Parse usage percentages
FIVE_HR=$(/usr/bin/python3 -c "import sys,json; d=json.loads('''$USAGE'''); print(int(d.get('five_hour',{}).get('utilization',0)))" 2>/dev/null)
SEVEN_DAY=$(/usr/bin/python3 -c "import sys,json; d=json.loads('''$USAGE'''); print(int(d.get('seven_day',{}).get('utilization',0)))" 2>/dev/null)

# Calculate remaining
FIVE_HR_REM=$((100 - ${FIVE_HR:-0}))
SEVEN_DAY_REM=$((100 - ${SEVEN_DAY:-0}))

# Color based on remaining (ANSI)
if [ "$FIVE_HR_REM" -gt 50 ]; then
    C5=$'\033[32m'  # green
elif [ "$FIVE_HR_REM" -gt 20 ]; then
    C5=$'\033[33m'  # yellow
else
    C5=$'\033[31m'  # red
fi

if [ "$SEVEN_DAY_REM" -gt 50 ]; then
    C7=$'\033[32m'
elif [ "$SEVEN_DAY_REM" -gt 20 ]; then
    C7=$'\033[33m'
else
    C7=$'\033[31m'
fi

# Build context display string for width calculation
CONTEXT_DISPLAY="${TOKEN_USED}/${TOKEN_AVAIL}"
CONTEXT_LEN=${#CONTEXT_DISPLAY}

# Calculate column widths for alignment
CWD_LEN=${#CWD}
MODEL_LEN=${#MODEL}
COL1=$((CWD_LEN > 17 ? CWD_LEN : 17))  # min width for "session-directory"
COL2=$((CONTEXT_LEN > 7 ? CONTEXT_LEN : 7))  # min width for "context"
COL3=$((MODEL_LEN > 5 ? MODEL_LEN : 5))  # min width for "model"

# Header line (bold blue)
printf "${CB}%-${COL1}s${R}  ${CB}%-${COL2}s${R}  ${CB}%-15s${R}  ${CB}%s${R}\n" "session-directory" "context" "usage" "model"
# Data line (numerator and usage colored, rest default text)
printf "${R}%-${COL1}s  ${CT}%s${R}/%-$((COL2 - ${#TOKEN_USED} - 1))s  5h:${C5}%-4s${R} 7d:${C7}%-4s${R}  %s\n" "$CWD" "$TOKEN_USED" "$TOKEN_AVAIL" "${FIVE_HR_REM}%" "${SEVEN_DAY_REM}%" "$MODEL"
