---
name: bdr2
description: Orchestrate BDR² lead-generation workflows — building lead lists, defining what a good-fit company looks like, finding and enriching leads, and drafting outreach emails. Use whenever the user refers to BDR², lead lists, qualifiers, ICQ, ICP, fit criteria, enrichment, or outreach emails and the bdr2 MCP tools are available.
---

# BDR² workflows

BDR² is a lead-generation SaaS. A user builds a **lead list**, describes their **Ideal Customer Profile (ICP)** — the shape of company they want more of — and BDR² finds leads, scores them against the ICP, enriches the good ones with contact details, and drafts outreach emails.

The `bdr2` MCP exposes low-level tools. This skill covers the overall goal, the loop to run, and the non-obvious rules that aren't in the tool schemas.

## How to talk to the user

Speak the language of sales operations, not the app's object model. The user describes outcomes; you translate to MCP calls behind the scenes.

| Internal term (tools/schemas) | How to phrase with the user |
|---|---|
| qualifier | "fit criterion" / "fit question" |
| ICQ | "ICP" / "fit profile" |
| enrichment config | don't name it — ask "who should I reach at each company?" |
| email generation config | don't name it — ask "who's sending, and what's the message?" |
| SmartQualifiers | don't name it — just an internal ordering tip |
| `desired_state`, `undetermined`, `unevaluated`, `failed` | "criterion passed / failed / couldn't tell / errored" |

You can fall back to the precise internal term when it genuinely helps — e.g. debugging a single misfiring criterion with the user. But lead with outcome-oriented phrasing.

Translating tool mechanics into user-facing language:

- Not "should I create an enrichment config?" → "who's the ideal person to reach at each company?"
- Not "this lead failed qualifier 2 (undetermined)" → "we couldn't tell whether this company sells to enterprises"
- Not "let's refine the ICQ" → "let's tighten up what counts as a good fit"
- Not "you accepted a lead that failed qualifier X" → "you accepted this even though it looks like they don't do Y — should we drop that requirement?"
- Not "I'll assign the email generation config" → (silent — just proceed, having asked about sender and message earlier)

## Top-level goal

For any list the user is building, aim to reach:

1. **At least ~5 accepted leads** (`accepted_status: true`) — examples of what the user wants more of. The lead finder uses them to seed discovery.
2. **A clear, stable fit profile** that reliably accepts good leads and rejects bad ones.

Everything else is in service of these two.

## The main loop

Run this loop whenever you're working a list:

1. Read leads with `get_leads(list_id)` (or `get_leads_without_feedback` to focus only on what needs review).
2. For leads that **don't meet the fit profile**: reject them with `reject_leads` without asking — the profile is the user's declared filter, act on it. Confirm with the user only for edge cases.
3. For leads that **meet the fit profile**: ask the user, then `accept_leads` / `reject_leads` based on their call.
4. For accepted leads: `enrich(lead_id, list_id)` → `get_leads_wait(list_id)` → `bulk_generate_email(lead_ids, list_id)` → `get_leads_wait` again.
5. When every lead on the list is either accepted or rejected, `find_new_leads(list_id, limit=N)` → `get_leads_wait`. Loop back to step 1.

**Do not call `find_new_leads` while there are still un-triaged leads in the list.** The lead finder uses accept/reject signal from existing leads to improve discovery — running it early degrades quality and wastes credits.

## Object model (internal — for your orientation, not the user's)

- **Lead list** — named container of leads. Has optional `lead_enrichment_config_id` and `email_generation_config_id`, plus an ICQ.
- **Lead** — company/contact on a list. Flows: added → enriched → scored against qualifiers → email generated → accepted/rejected.
- **Qualifier** — account-level yes/no question (e.g. "Does this company sell to enterprises?"). Can be attached to multiple lists' ICQs.
- **ICQ (Ideal Customer Qualifiers)** — the list's filter: for each qualifier, which outcomes (`undetermined` / `true` / `false`) count as "still qualified". Set via `set_icq`. User-facing, this is the **ICP**.
- **Enrichment config** — describes who to find at a company (`contact_search_hint`).
- **Email generation config** — sender persona and messaging for drafts.

## Evaluation states

Qualifier evaluations have **six** states; ICQ `desired_state` only covers the three that BDR² actually observes:

| State | Meaning | In ICQ? | How to say it to the user |
|---|---|---|---|
| `unevaluated` | never assessed | — | "not checked yet" |
| `undetermined` | assessed, couldn't decide either way | yes (bool) | "couldn't tell" |
| `true` | assessed true | yes (bool) | "passed" / "yes" |
| `false` | assessed false | yes (bool) | "failed" / "no" |
| `failed` | assessment errored | — | "errored" |
| `processing` | in progress | — | "checking" |

Enrichments and email generations have three states: `completed`, `failed`, `processing`.

Retry failed evaluations / enrichments at most ~2× for the same lead before giving up.

## Credit-saving: criterion ordering

The MCP evaluates a lead's criteria **left-to-right in the order you pass to `set_icq`** and stops as soon as the fit profile is violated — a lead that fails criterion 2 of 5 only costs 2 qualify credits, not 5. To benefit:

- Order criteria in `set_icq` with **most-likely-to-disqualify first** (cheap eliminations first).
- Don't bulk-evaluate a lead that has no eval in progress — kicking off evaluation of *any one* unevaluated criterion triggers the short-circuit chain automatically. If you must pick one, pick the criterion most likely to come back `false`.
- Only use `bulk_evaluate_qualifier(..., force_refresh=true)` when a criterion's question has actually changed and you need to re-score existing leads.

## Credit economics

Three credit types. Check balance anytime with `get_remaining_credits`. When talking to the user, say "lead-finding credits are running low" — not "you're low on `find_leads` credits".

| Credit | Charged per | Guidance |
|---|---|---|
| `find_leads` | each lead the finder returns | don't `find_new_leads` until the list is fully accept/reject'd |
| `qualify` | each criterion evaluation | let short-circuit evaluation drive it; don't bulk re-eval unnecessarily |
| `enrichment` | each `enrich` call | usually the scarcest — only enrich leads that are **qualified AND accepted** |
| `phone_enrichment` | each `enrich_phone` call | lead must already be enriched |

Email generation is **free** — no credit.

## Setting up a new list (conversational intake)

Ask the user about outcomes, then wire up the machinery behind the scenes. **Don't present a checklist of configs to create** — have a conversation.

**Intake to collect** (in roughly this order, conversationally — not as a survey):

1. **List name** — what should I call this list?
2. **Target company shape** — what kind of companies do you want more of? Industry, size, geography, business model, tech stack, customer base — anything that makes a company a good or bad fit. Each distinct signal becomes one yes/no criterion.
3. **Who to reach** — at each of these companies, who's the ideal person to contact? (Role, seniority, function, any disqualifying titles.)
4. **Sender and message** — who's reaching out (name, title, company, relevant angle) and what do you want these emails to accomplish?
5. **Starter leads** — can you name 5+ companies that already fit this well? If yes, seed with those; if not, run a starter search.

**What to do behind the scenes** once you have enough of the intake:

1. `create_list(name)` → new `list_id`.
2. From "who to reach": `create_enrichment_config(short_name, contact_search_hint, lead_list_id=list_id)`. Or browse existing with `list_enrichment_configs` + `assign_enrichment_config_to_list` if one already matches.
3. From "sender and message": `create_email_config(..., lead_list_id=list_id)`. Or reuse via `list_email_configs` + `assign_email_config_to_list`.
4. From "target company shape": turn each fit signal into a criterion.
   - `get_qualifiers` to see what's already on the account (criteria are account-level and reusable).
   - `create_qualifier(short_name, question)` for anything new.
   - `set_icq(list_id, qualifiers=[{qualifier_id, desired_state: {undetermined, true, false}}])`. All three boolean keys are required; `unevaluated` is **not** valid.
5. From "starter leads": `add_lead(list_id, company_url, ...)` per example. If none provided, `find_new_leads(list_id, limit=5)` (max 20) for starter candidates.
6. `get_leads_wait(list_id)` to block until the list settles (no searches, qualifier evals, or lead evals in progress). Default timeout 15 min — call again if it times out rather than treating it as fatal.

You don't need every answer before starting — you can collect the target shape and starter leads, kick off a search while you ask about sender/message, etc. Use judgement about when you have enough to proceed.

Then drop into the main loop.

## Iterating on the fit profile

The fit profile won't be perfect on the first pass. Watch for these signals:

- User **accepts** a lead that **failed** a criterion → probably a misphrased criterion. Ask "you accepted this even though it looks like they don't do X — should we loosen or drop that requirement?"
- User **rejects** a lead that **passed** every criterion → either adjust an existing criterion or add a new one. Ask "this one passed everything but you rejected it — what's off about it that we should be checking for?"

After any change to the fit profile:

- **New or edited criterion: verify on 10–20 leads before trusting it.** `bulk_evaluate_qualifier(pairs=[{lead_id, qualifier_id}, ...], force_refresh=true)` → `get_leads_wait` → sanity-check results with the user ("here are the companies it just passed/failed — does that match your gut?").
- Revisit criteria periodically — they can drift in quality as the lead mix changes.

## Reviewing and triaging leads

- `get_leads(list_id)` — current leads with heavy fields stripped for context economy.
- `get_leads_without_feedback(list_id)` — only leads awaiting accept/reject. Good default for "what needs review".
- `get_lead_details(lead_id)` — full detail for one lead (email body, long reasoning, etc).
- `accept_leads` / `reject_leads` / `clear_leads_feedback` — bulk feedback.
- `move_leads(lead_ids, source, target)` — source must ≠ target.
- **Archive default**: users mean **unarchived** lists/leads unless they explicitly say otherwise. Pass `include_archived=true` only on explicit ask.

## Generating outreach

- `generate_email(lead_id, list_id)` — free, single lead.
- `bulk_generate_email(lead_ids, list_id)` — free, many leads.
- Both require the list to have a sender/message already set up (internally: `email_generation_config_id` assigned). If it's missing, ask the user about sender and message rather than naming the missing config.
- `get_leads_wait` also blocks on email generation — read back the drafted content with `get_lead_details` afterwards.

## Phone enrichment

- `enrich_phone(lead_id)` — requires prior lead enrichment, costs 1 `phone_enrichment` credit. Check balance first if doing many.

## Sharing results with the user

Prefer BDR² URLs over inline data dumps for anything non-trivial:

- Lead list: `https://app.bdr2.com/lists/<list_id>`
- Lead: `https://app.bdr2.com/lists/<list_id>/lead/<lead_id>`

Don't offer CSV export — the user has that in the BDR² UI already.

## Preconditions cheat-sheet

| Tool | Won't work unless |
|---|---|
| `enrich` | list has `lead_enrichment_config_id` assigned |
| `generate_email` / `bulk_generate_email` | list has `email_generation_config_id` assigned |
| `enrich_phone` | lead is already enriched; account has `phone_enrichment` credits |
| `find_new_leads` | `limit` ≤ 20 |
| `set_icq` | every qualifier's `desired_state` has all three of `undetermined`, `true`, `false` (booleans) |
| `move_leads` | source_list_id ≠ target_list_id |

## Good defaults

- Vague about which list? Start with `get_lead_lists` and ask them to pick (unarchived only).
- After any async op (`find_new_leads`, `bulk_evaluate_qualifier`, `enrich`, `generate_email`): call `get_leads_wait` before reporting.
- `get_leads` for overviews, `get_lead_details` for deep dives — don't pull full details for a whole list.
- Platform bugs / feature requests: route via `create_support_ticket` / `add_message_to_support_ticket` / `get_support_tickets` rather than trying to debug the product.
