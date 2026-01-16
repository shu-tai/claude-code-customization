# Undocumented Claude APIs

Findings from reverse engineering Claude Code v2.1.9 network traffic using mitmproxy.

## Authentication

OAuth tokens are stored in macOS Keychain under the service name `Claude Code-credentials`.

**Retrieve token:**
```bash
security find-generic-password -s "Claude Code-credentials" -w
```

**Response format:**
```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1768570169474,
    "scopes": ["user:inference", "user:profile", "user:sessions:claude_code"],
    "subscriptionType": "pro",
    "rateLimitTier": "default_claude_ai"
  }
}
```

---

## Usage / Quota API

Returns subscription usage percentages and reset times. This is what powers the `/usage` command.

**Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`

**Headers:**
```
Authorization: Bearer sk-ant-oat01-...
anthropic-beta: oauth-2025-04-20
Content-Type: application/json
```

**Response:**
```json
{
  "five_hour": {
    "utilization": 58.0,
    "resets_at": "2026-01-16T10:00:00.428135+00:00"
  },
  "seven_day": {
    "utilization": 8.0,
    "resets_at": "2026-01-22T14:00:00.428159+00:00"
  },
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": null,
  "iguana_necktie": null,
  "extra_usage": {
    "is_enabled": false,
    "monthly_limit": null,
    "used_credits": null,
    "utilization": null
  }
}
```

**Fields:**
- `five_hour.utilization` - Percentage of 5-hour rolling window used (0-100)
- `five_hour.resets_at` - ISO 8601 timestamp when 5-hour limit resets
- `seven_day.utilization` - Percentage of 7-day rolling window used (0-100)
- `seven_day.resets_at` - ISO 8601 timestamp when 7-day limit resets
- `extra_usage` - Extra usage/overage settings (for paid tiers)

---

## Account Settings API

Returns account configuration and subscription details.

**Endpoint:** `GET https://api.anthropic.com/api/oauth/account/settings`

**Headers:** Same as Usage API

**Response:** (737 bytes, structure not fully captured)

---

## Grove Privacy Settings API

Returns privacy/data training opt-out settings.

**Endpoint:** `GET https://api.anthropic.com/api/claude_code_grove`

**Headers:** Same as Usage API

**Response:** (101 bytes, structure not fully captured)

---

## Event Logging API

Batch event logging for telemetry.

**Endpoint:** `POST https://api.anthropic.com/api/event_logging/batch`

**Headers:** Same as Usage API

---

## SDK Eval API

Unknown purpose, possibly feature flags or A/B testing.

**Endpoint:** `POST https://api.anthropic.com/api/eval/sdk-{id}`

---

## Statsig Integration

Claude Code uses Statsig for feature flags and analytics.

**Endpoints:**
- `POST https://statsig.anthropic.com/v1/initialize?k=client-RRNS7R6...`
- `POST https://statsig.anthropic.com/v1/rgstr?k=client-RRNS7R6...`

---

## Documented APIs (for reference)

These are public/documented:

- `POST https://api.anthropic.com/v1/messages` - Main chat API
- `POST https://api.anthropic.com/v1/messages/count_tokens` - Token counting

---

## How to Capture Traffic

1. Install mitmproxy: `brew install mitmproxy`

2. Start capture:
```bash
mitmdump --set confdir=/tmp/mitmproxy-conf -p 8888 --ssl-insecure
```

3. Run Claude Code through proxy:
```bash
HTTPS_PROXY=http://localhost:8888 \
HTTP_PROXY=http://localhost:8888 \
NODE_TLS_REJECT_UNAUTHORIZED=0 \
claude
```

4. Analyze captured traffic:
```bash
mitmdump -r /tmp/capture.flow -n --set flow_detail=3
```

---

## Disclaimer

These APIs are undocumented and may change without notice. Use at your own risk.

*Last updated: 2026-01-16*
*Claude Code version: 2.1.9*
