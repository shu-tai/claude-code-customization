#!/bin/bash
# Status line script showing Claude usage percentages
# Calls the same API endpoint as /usage

# Read stdin (status line JSON)
STDIN=$(cat)

# Debug: log raw input
echo "$STDIN" > /tmp/statusline_debug.json

# Extract working directory from stdin JSON (relative path only)
CWD=$(/usr/bin/python3 -c "import sys,json,os; d=json.loads('''$STDIN'''); cwd=d.get('workspace',{}).get('current_dir',''); print(os.path.basename(cwd) if cwd else '')" 2>/dev/null)

# Extract context window tokens (used/available) and remaining percentage
read TOKENS TOKEN_REM < <(/usr/bin/python3 -c "
import json
d=json.loads('''$STDIN''')
cw=d.get('context_window',{})
used=cw.get('total_input_tokens',0) + cw.get('total_output_tokens',0)
avail=cw.get('context_window_size',0)
rem=cw.get('remaining_percentage',100)
print(f'{used/1000:.1f}/{avail//1000}k {rem}')
" 2>/dev/null)

# Color for token display
TOKEN_REM=${TOKEN_REM:-100}
if [ "$TOKEN_REM" -gt 50 ]; then
    CT="\033[32m"  # green
elif [ "$TOKEN_REM" -gt 20 ]; then
    CT="\033[33m"  # yellow
else
    CT="\033[31m"  # red
fi
R="\033[0m"

# Get OAuth token from keychain
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [ -z "$CREDS" ]; then
    echo -e "${CWD} (${CT}${TOKENS}${R})  no auth"
    exit 0
fi

TOKEN=$(echo "$CREDS" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
    echo -e "${CWD} (${CT}${TOKENS}${R})  no token"
    exit 0
fi

# Fetch usage data
USAGE=$(curl -s --max-time 2 \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

if [ -z "$USAGE" ]; then
    echo -e "${CWD} (${CT}${TOKENS}${R})  fetch failed"
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
    C5="\033[32m"  # green
elif [ "$FIVE_HR_REM" -gt 20 ]; then
    C5="\033[33m"  # yellow
else
    C5="\033[31m"  # red
fi

if [ "$SEVEN_DAY_REM" -gt 50 ]; then
    C7="\033[32m"
elif [ "$SEVEN_DAY_REM" -gt 20 ]; then
    C7="\033[33m"
else
    C7="\033[31m"
fi

echo -e "${CWD} (${CT}${TOKENS}${R})  5h:${C5}${FIVE_HR_REM}%${R} 7d:${C7}${SEVEN_DAY_REM}%${R}"
