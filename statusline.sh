#!/bin/bash
# Status line script showing Claude usage percentages
# Calls the same API endpoint as /usage

# Read stdin (status line JSON)
STDIN=$(cat)

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
TOKEN_USED_PCT=$((100 - TOKEN_REM))
if [ -z "$CREDS" ]; then
    echo -e "${CWD}  ${CT}${TOKEN_USED}${R}/${TOKEN_AVAIL} (${CT}${TOKEN_USED_PCT}%${R})  no auth  ${MODEL}"
    exit 0
fi

TOKEN=$(echo "$CREDS" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
    echo -e "${CWD}  ${CT}${TOKEN_USED}${R}/${TOKEN_AVAIL} (${CT}${TOKEN_USED_PCT}%${R})  no token  ${MODEL}"
    exit 0
fi

# Fetch usage data
USAGE=$(curl -s --max-time 2 \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

if [ -z "$USAGE" ]; then
    echo -e "${CWD}  ${CT}${TOKEN_USED}${R}/${TOKEN_AVAIL} (${CT}${TOKEN_USED_PCT}%${R})  fetch failed  ${MODEL}"
    exit 0
fi

# Parse usage percentages and reset times
read FIVE_HR_USED FIVE_HR_RESET < <(/usr/bin/python3 -c "
import json
from datetime import datetime, timezone
d=json.loads('''$USAGE''')
fh=d.get('five_hour',{})
util=int(fh.get('utilization',0))
reset_str=fh.get('resets_at','')
if reset_str:
    reset=datetime.fromisoformat(reset_str.replace('Z','+00:00'))
    now=datetime.now(timezone.utc)
    delta=reset-now
    secs=max(0,int(delta.total_seconds()))
    h=secs/3600
    print(f'{util} {h:.1f}h')
else:
    print(f'{util} --')
" 2>/dev/null)

read SEVEN_DAY_USED SEVEN_DAY_RESET < <(/usr/bin/python3 -c "
import json
from datetime import datetime, timezone
d=json.loads('''$USAGE''')
sd=d.get('seven_day',{})
util=int(sd.get('utilization',0))
reset_str=sd.get('resets_at','')
if reset_str:
    reset=datetime.fromisoformat(reset_str.replace('Z','+00:00'))
    now=datetime.now(timezone.utc)
    delta=reset-now
    secs=max(0,int(delta.total_seconds()))
    h=secs/3600
    print(f'{util} {h:.1f}h')
else:
    print(f'{util} --')
" 2>/dev/null)

FIVE_HR_USED=${FIVE_HR_USED:-0}
SEVEN_DAY_USED=${SEVEN_DAY_USED:-0}
FIVE_HR_RESET=${FIVE_HR_RESET:---}
SEVEN_DAY_RESET=${SEVEN_DAY_RESET:---}

# Color based on usage (ANSI) - lower is better
if [ "$FIVE_HR_USED" -lt 50 ]; then
    C5=$'\033[32m'  # green
elif [ "$FIVE_HR_USED" -lt 80 ]; then
    C5=$'\033[33m'  # yellow
else
    C5=$'\033[31m'  # red
fi

if [ "$SEVEN_DAY_USED" -lt 50 ]; then
    C7=$'\033[32m'
elif [ "$SEVEN_DAY_USED" -lt 80 ]; then
    C7=$'\033[33m'
else
    C7=$'\033[31m'
fi

# Build display strings for width calculation
CONTEXT_DISPLAY="${TOKEN_USED}/${TOKEN_AVAIL} (${TOKEN_USED_PCT}%)"
USAGE_DISPLAY="${FIVE_HR_RESET}:${FIVE_HR_USED}% ${SEVEN_DAY_RESET}:${SEVEN_DAY_USED}%"

# Calculate column widths for alignment
COL1=$((${#CWD} > 17 ? ${#CWD} : 17))  # min width for "session-directory"
COL2=$((${#CONTEXT_DISPLAY} > 7 ? ${#CONTEXT_DISPLAY} : 7))  # min width for "context"
COL3=$((${#USAGE_DISPLAY} > 5 ? ${#USAGE_DISPLAY} : 5))  # min width for "usage"

# Header line (bold blue)
printf "${CB}%-${COL1}s${R}  ${CB}%-${COL2}s${R}  ${CB}%-${COL3}s${R}  ${CB}%s${R}\n" "session-directory" "context" "usage" "model"
# Data line (numerator and usage colored, rest default text)
printf "${R}%-${COL1}s  ${CT}%s${R}/%s (${CT}%s%%${R})%*s  ${C5}%s:%s${R} ${C7}%s:%s${R}%*s  %s\n" "$CWD" "$TOKEN_USED" "$TOKEN_AVAIL" "$TOKEN_USED_PCT" $((COL2 - ${#CONTEXT_DISPLAY})) "" "$FIVE_HR_RESET" "${FIVE_HR_USED}%" "$SEVEN_DAY_RESET" "${SEVEN_DAY_USED}%" $((COL3 - ${#USAGE_DISPLAY})) "" "$MODEL"
