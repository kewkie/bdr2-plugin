# bdr2-plugin

Agent packaging for [BDR²](https://bdr2.com) workflows:

- **Claude Code plugin** (`.claude-plugin/` + `skills/bdr2/SKILL.md`)
- **Codex setup** (`.codex/config.toml` + `AGENTS.md`)

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

Codex uses MCP config + `AGENTS.md` (no marketplace command). To install into the current repo from GitHub in one shot:

```
curl -fsSL https://raw.githubusercontent.com/kewkie/bdr2-plugin/main/scripts/install-codex.sh | bash
```

The installer will:

- add/update `.codex/config.toml` with the BDR2 MCP server
- append/update a managed BDR2 section in `AGENTS.md`

Then trust the project in Codex so project config is loaded:

```
codex trust
```

On first MCP use, complete the browser OAuth flow for BDR².

## What's in the box

```
.claude-plugin/
├── plugin.json          plugin manifest — name, version, MCP server config
└── marketplace.json     single-plugin marketplace (so this repo self-installs)
.codex/
└── config.toml          Codex MCP server config
AGENTS.md                Codex workflow guidance
scripts/
└── install-codex.sh     one-shot Codex installer (from GitHub)
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
