---
summary: "Ollama provider notes: settings scrape, cookie auth, and Cloud Usage parsing."
read_when:
  - Adding or modifying the Ollama provider
  - Debugging Ollama cookie import or settings parsing
  - Adjusting Ollama menu labels or usage mapping
---

# Ollama Provider

CodexBar supports two Ollama data sources:

1. **Local Ollama API (default)**: queries your local Ollama daemon via HTTP (typically `http://127.0.0.1:11434`) to detect that Ollama is running and how many models are installed.
2. **Ollama.com Cloud Usage (optional)**: scrapes the **Plan & Billing** page to extract Cloud Usage limits for session and weekly windows (requires browser cookies).

## Features

### Local API
- Detects **Ollama is reachable** and shows the daemon version.
- Shows a **model count** (installed models) in the provider “Plan” line.
- No auth required.

### Ollama.com Cloud Usage (optional)
- **Plan badge**: Reads the plan tier (Free/Pro/Max) from the Cloud Usage header.
- **Session + weekly usage**: Parses the percent-used values shown in the usage bars.
- **Reset timestamps**: Uses the `data-time` attribute on the “Resets in …” elements.
- **Browser cookie auth**: No API keys required.

## Setup

### Local API (default)

1. Open **Settings → Providers**.
2. Enable **Ollama**.
3. (Optional) Set **Host** if your Ollama daemon is not on the default:
   - Default: `http://127.0.0.1:11434`
   - Or set env var `OLLAMA_HOST` (e.g. `OLLAMA_HOST=localhost:11434`).

### Ollama.com Cloud Usage (optional)

1. In **Ollama** settings, set **Cookie source** to **Auto** (imports browser cookies) or **Manual**.

### Manual cookie import (optional)

1. Open `https://ollama.com/settings` in your browser.
2. Copy a `Cookie:` header from the Network tab.
3. Paste it into **Ollama → Cookie source → Manual**.

## How it works

### Local API

- Calls:
  - `GET /api/version`
  - `GET /api/tags`
- Maps results into a `UsageSnapshot` with a synthetic “Plan” string like:
  - `Local · 12 models · v0.1.32`

### Ollama.com Cloud Usage (optional)

- Fetches `https://ollama.com/settings` using browser cookies.
- Parses:
  - Plan badge under **Cloud Usage**.
  - **Session usage** and **Weekly usage** percentages.
  - `data-time` ISO timestamps for reset times.

## Troubleshooting

### “No Ollama session cookie found”

Log in to `https://ollama.com/settings` in Chrome, then refresh in CodexBar.
If your active session is only in Safari (or another browser), use **Cookie source → Manual** and paste a cookie header.

### “Ollama session cookie expired”

Sign out and back in at `https://ollama.com/settings`, then refresh.

### “Could not parse Ollama usage”

The settings page HTML may have changed. Capture the latest page HTML and update `OllamaUsageParser`.
