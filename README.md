# bdr2-plugin

Agent packaging for [BDR²](https://bdr2.com) workflows:

- **Claude Code plugin** (`.claude-plugin/` + `skills/bdr2/SKILL.md`)
- **Codex plugin + skill** (`.codex-plugin/plugin.json` + `.mcp.json` + `.agents/skills/bdr2/SKILL.md`)

## What you get

- **MCP connection** to `https://app.bdr2.com/api/mcp/` (OAuth — you'll be prompted to authorise in your browser on first use).
- **`bdr2` skill** that activates automatically when you ask about lead lists, qualifiers, enrichment, or outreach emails. It tells Claude the right call order, preconditions, and async wait points so workflows complete cleanly without trial-and-error.

## Install from GitHub (Claude)

```
# Add this repo as a marketplace (GitHub shorthand)
/plugin marketplace add kewkie/bdr2-plugin

# Install the plugin
/plugin install bdr2@bdr2
```

You can also add by full URL:

```
/plugin marketplace add https://github.com/kewkie/bdr2-plugin
/plugin install bdr2@bdr2
```

On first tool call, Claude Code will open a browser window for BDR² OAuth. Sign in with your normal BDR² account; the token is scoped to `use_mcp` and stored locally by Claude Code.

## Install from GitHub (Codex)

Use the Codex marketplace flow (recommended):

```
codex plugin marketplace add kewkie/bdr2-plugin
```

Then open Codex and install `bdr2` from the plugin browser:

```
codex
/plugins
```

On first use, authenticate MCP:

```
codex mcp login bdr2
```

## What's in the box

```
.claude-plugin/
├── plugin.json          plugin manifest — name, version, MCP server config
└── marketplace.json     single-plugin marketplace (so this repo self-installs)
.codex-plugin/
└── plugin.json          Codex-native plugin manifest
.mcp.json                MCP server config used by Codex plugin
.agents/
├── plugins/
│   └── marketplace.json Codex marketplace catalog
└── skills/
    └── bdr2/
        ├── SKILL.md     Codex bdr2 skill instructions
        └── agents/
            └── openai.yaml  skill metadata + MCP dependency hints
skills/
└── bdr2/
    └── SKILL.md         orchestration guide loaded on-demand
```

No local binary is shipped — the server runs at `app.bdr2.com` and is reached over Streamable HTTP.

## Developing

Point Claude Code at a local checkout to test changes without republishing:

```
/plugin marketplace add /Users/you/code/bdr2-plugin
/plugin install bdr2@bdr2
```

Edit `skills/bdr2/SKILL.md` (Claude) and `.agents/skills/bdr2/SKILL.md` (Codex) and reload clients (`/plugin reload bdr2` for Claude, restart Codex) to see changes.

## Updating the skill

When new tools are added to the bdr2 MCP, update `skills/bdr2/SKILL.md` with:
- Where the tool fits in the workflow sections (setup / review / iterate / outreach).
- Any preconditions or credit costs not obvious from the tool schema.
- A row in the preconditions cheat-sheet if it has a gotcha.

Bump `version` in `plugin.json` and tag a release so installed users can pick up the update.

## License

MIT. See `LICENSE`.
