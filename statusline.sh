#!/bin/bash
# Status line script showing Claude usage percentages
# Calls the same API endpoint as /usage

# Read stdin (status line JSON)
STDIN=$(cat)

# Extract working directory from stdin JSON (relative path only)
CWD=$(/usr/bin/python3 -c "import sys,json,os; d=json.loads('''$STDIN'''); cwd=d.get('workspace',{}).get('current_dir',''); print(os.path.basename(cwd) if cwd else '')" 2>/dev/null)

# Get OAuth token from keychain
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [ -z "$CREDS" ]; then
    echo "${CWD}  no auth"
    exit 0
fi

TOKEN=$(echo "$CREDS" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
    echo "${CWD}  no token"
    exit 0
fi

# Fetch usage data
USAGE=$(curl -s --max-time 2 \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

if [ -z "$USAGE" ]; then
    echo "${CWD}  fetch failed"
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
R="\033[0m"

echo -e "${CWD}  5h:${C5}${FIVE_HR_REM}%${R} 7d:${C7}${SEVEN_DAY_REM}%${R}"
