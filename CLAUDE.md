# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Customizations and extensions for Claude Code. Current focus: displaying remaining usage limit percentage in the interface.

## Claude Code Extension Points

Claude Code is a compiled binary with these documented extension mechanisms:

### Status Line (Primary target for usage display)
Configure in `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```
Script receives JSON via stdin with: model info, workspace, cost, context_window (tokens used/available). Outputs first line of stdout as status text. Supports ANSI colors.

### Other Extension Points
- **Hooks** - Intercept PreToolUse, PostToolUse, UserPromptSubmit events
- **Plugins** - Package commands, skills, agents, MCP servers
- **Custom slash commands** - Markdown files in `commands/`

## API Rate Limit Headers

Anthropic API returns these headers (not currently exposed to status line):
- `anthropic-ratelimit-tokens-remaining`
- `anthropic-ratelimit-requests-remaining`
- `anthropic-ratelimit-*-reset` (RFC 3339 timestamps)

## Usage API (Reverse Engineered)

**Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`

**Auth:** OAuth token from macOS Keychain (`Claude Code-credentials`)

**Response:**
```json
{
  "five_hour": {"utilization": 58.0, "resets_at": "2026-01-16T10:00:00+00:00"},
  "seven_day": {"utilization": 8.0, "resets_at": "2026-01-22T14:00:00+00:00"}
}
```

`statusline.sh` fetches this and displays remaining % in status line.
