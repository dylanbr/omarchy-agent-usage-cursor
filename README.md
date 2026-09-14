# Agent Usage: Cursor

An Omarchy service plugin that adds a **Cursor** usage tab to the built-in
Agents panel (alongside Claude, Codex, and Fireworks).

## How it works

The `omarchy.agents` panel draws one tab per JSON record in
`~/.local/state/omarchy/agents/usage/`. Omarchy only runs the packaged
`omarchy-agent-usage-*` collectors under `$OMARCHY_PATH/bin`, so Cursor needs
its own publisher.

This plugin is a headless `service` that:

1. Runs `collectors/omarchy-agent-usage-cursor` every 5 minutes (and on shell start).
2. Validates the JSON record.
3. Atomically writes `~/.local/state/omarchy/agents/usage/cursor.json`.

## What it shows

- **Plan tier** — from Cursor's stripe profile (`Pro`, `Pro+`, …).
- **Limits** — billing-cycle meters from `https://cursor.com/api/usage-summary`:
  - Cursor Models (`autoPercentUsed`)
  - API Models (`apiPercentUsed`)
  - On-Demand (when enabled with a numeric cap)
- **Tokens by day / model** — from dashboard usage events for the last 30 days
  (best-effort; limits still work if events fail).

## Requirements

- Omarchy with `omarchy.agents` enabled.
- `python3`
- A Cursor CLI login (`~/.config/cursor/auth.json`), or `CURSOR_ACCESS_TOKEN` /
  `CURSOR_API_KEY` in the environment.

## Install

From a published git remote:

```sh
omarchy plugin add https://github.com/<you>/omarchy-agent-usage-cursor.git --enable
```

From this local checkout:

```sh
omarchy plugin add ~/Work/omarchy-agent-usage-cursor --enable --yes
```

Then restart the shell (or wait for the service timer) and open the Agents panel.
Middle-click / `h`/`l` switches subscriptions when more than one is present.

## Remove

```sh
omarchy plugin remove dylanbr.agent-usage-cursor
rm -f ~/.local/state/omarchy/agents/usage/cursor.json
```

## Development

```sh
omarchy plugin validate .
python3 collectors/omarchy-agent-usage-cursor | jq .
python3 collectors/omarchy-agent-usage-cursor --limits-only | jq .
```

## Notes

Cursor's usage endpoints are undocumented dashboard APIs and may change.
Auth uses the CLI access token via a `WorkosCursorSessionToken` cookie —
the same approach community tools (e.g. Oh My Pi) use.

## License

MIT
