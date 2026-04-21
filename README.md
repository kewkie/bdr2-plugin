# bdr2-plugin

Claude Code plugin for [BDR²](https://bdr2.com) — bundles the BDR² MCP server with an orchestration skill that teaches Claude how to chain the low-level tools into real lead-generation workflows.

## What you get

- **MCP connection** to `https://app.bdr2.com/api/mcp/` (OAuth — you'll be prompted to authorise in your browser on first use).
- **`bdr2` skill** that activates automatically when you ask about lead lists, qualifiers, enrichment, or outreach emails. It tells Claude the right call order, preconditions, and async wait points so workflows complete cleanly without trial-and-error.

## Install

```
# Add this repo as a marketplace
/plugin marketplace add kewkie/bdr2-plugin

# Install the plugin
/plugin install bdr2@bdr2
```

On first tool call, Claude Code will open a browser window for BDR² OAuth. Sign in with your normal BDR² account; the token is scoped to `use_mcp` and stored locally by Claude Code.

## What's in the box

```
.claude-plugin/
├── plugin.json          plugin manifest — name, version, MCP server config
└── marketplace.json     single-plugin marketplace (so this repo self-installs)
skills/
└── bdr2/
    └── SKILL.md         orchestration guide loaded on-demand
```

The plugin manifest declares the MCP server inline. No local binary is shipped — the server runs at `app.bdr2.com` and is reached over Streamable HTTP.

## Developing

Point Claude Code at a local checkout to test changes without republishing:

```
/plugin marketplace add /Users/you/code/bdr2-plugin
/plugin install bdr2@bdr2
```

Edit `skills/bdr2/SKILL.md` and reload the skill (`/plugin reload bdr2` or restart Claude Code) to see changes.

## Updating the skill

When new tools are added to the bdr2 MCP, update `skills/bdr2/SKILL.md` with:
- Where the tool fits in the workflow sections (setup / review / iterate / outreach).
- Any preconditions or credit costs not obvious from the tool schema.
- A row in the preconditions cheat-sheet if it has a gotcha.

Bump `version` in `plugin.json` and tag a release so installed users can pick up the update.

## License

MIT. See `LICENSE`.
