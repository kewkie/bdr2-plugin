---
name: bdr2
description: Orchestrate BDR² lead-generation workflows — managing lead lists, finding and enriching leads, defining ideal customer qualifiers (ICQ), scoring leads against them, and generating outreach emails. Use whenever the user refers to BDR², lead lists, qualifiers, enrichment, or outreach emails and the bdr2 MCP tools are available.
---

# BDR² workflows

BDR² is a lead-generation SaaS. A user builds a **lead list**, defines their **Ideal Customer Qualifiers (ICQ)** — yes/no questions about what a good-fit company looks like — then has BDR² find leads, auto-score them against the ICQ, enrich the good ones with contact details, and draft outreach emails.

The `bdr2` MCP exposes low-level tools. This skill covers the overall goal, the loop to run, and the non-obvious rules that aren't in the tool schemas.

## Top-level goal

For any list the user is building, aim to reach:

1. **At least ~5 accepted leads** (`accepted_status: true`) — examples of what the user wants more of. The lead finder uses them to seed discovery.
2. **A stable ICQ** that reliably accepts good leads and rejects bad ones.

Everything else is in service of these two.

## The main loop

Run this loop whenever you're working a list:

1. Read leads with `get_leads(list_id)` (or `get_leads_without_feedback` to focus only on what needs review).
2. For leads that **don't pass the ICQ**: reject them with `reject_leads` without asking — the ICQ is the user's declared filter, act on it. Confirm with the user only for edge cases.
3. For leads that **pass the ICQ**: ask the user, then `accept_leads` / `reject_leads` based on their call.
4. For accepted leads: `enrich(lead_id, list_id)` → `get_leads_wait(list_id)` → `bulk_generate_email(lead_ids, list_id)` → `get_leads_wait` again.
5. When every lead on the list is either accepted or rejected, `find_new_leads(list_id, limit=N)` → `get_leads_wait`. Loop back to step 1.

**Do not call `find_new_leads` while there are still un-triaged leads in the list.** The lead finder uses accept/reject signal from existing leads to improve discovery — running it early degrades quality and wastes credits.

## Object model

- **Lead list** — named container of leads. Has optional `lead_enrichment_config_id` and `email_generation_config_id`, plus an ICQ.
- **Lead** — company/contact on a list. Flows: added → enriched → scored against qualifiers → email generated → accepted/rejected.
- **Qualifier** — account-level yes/no question (e.g. "Does this company sell to enterprises?"). Can be attached to multiple lists' ICQs.
- **ICQ (Ideal Customer Qualifiers)** — the list's filter: for each qualifier, which outcomes (`undetermined` / `true` / `false`) count as "still qualified". Set via `set_icq`.
- **Enrichment config** — describes who to find at a company (`contact_search_hint`).
- **Email generation config** — sender persona and messaging for drafts.

## Evaluation states

Qualifier evaluations have **six** states; ICQ `desired_state` only covers the three that BDR² actually observes:

| State | Meaning | In ICQ? |
|---|---|---|
| `unevaluated` | never assessed | — |
| `undetermined` | assessed, couldn't decide either way | yes (bool) |
| `true` | assessed true | yes (bool) |
| `false` | assessed false | yes (bool) |
| `failed` | assessment errored | — |
| `processing` | in progress | — |

Enrichments and email generations have three states: `completed`, `failed`, `processing`.

Retry failed evaluations / enrichments at most ~2× for the same lead before giving up.

## SmartQualifiers (credit-saving mechanism)

SmartQualifiers evaluates a lead's qualifiers **left-to-right in ICQ order** and stops as soon as the ICQ is violated — a lead that fails qualifier 2 of 5 only costs 2 qualify credits, not 5. To benefit:

- Order qualifiers in `set_icq` with **most-likely-to-disqualify first** (cheap eliminations first).
- Don't bulk-evaluate a lead that already has no eval in progress — starting evaluation of *any one* unevaluated qualifier triggers the SmartQualifier chain automatically. If you must pick one, pick the qualifier most likely to come back `false`.
- Only use `bulk_evaluate_qualifier(..., force_refresh=true)` when a qualifier's question has actually changed and you need to re-score existing leads.

## Credit economics

Three credit types. Check balance anytime with `get_remaining_credits`.

| Credit | Charged per | Guidance |
|---|---|---|
| `find_leads` | each lead the finder returns | don't `find_new_leads` until the list is fully accept/reject'd |
| `qualify` | each qualifier evaluation | let SmartQualifiers drive it; don't bulk re-eval unnecessarily |
| `enrichment` | each `enrich` call | usually the scarcest — only enrich leads that are **qualified AND accepted** |
| `phone_enrichment` | each `enrich_phone` call | lead must already be enriched |

Email generation is **free** — no credit.

## Setting up a new list

1. `create_list(name)` → new `list_id`.
2. Enrichment config: `list_enrichment_configs` to browse; `create_enrichment_config(short_name, contact_search_hint, lead_list_id=list_id)` to make+assign in one call, or `assign_enrichment_config_to_list` for an existing one.
3. Email config: same pattern with `list_email_configs` / `create_email_config(..., lead_list_id=list_id)` / `assign_email_config_to_list`.
4. Qualifiers and ICQ:
   - `get_qualifiers` to see what's already on the account.
   - `create_qualifier(short_name, question)` for anything missing.
   - `set_icq(list_id, qualifiers=[{qualifier_id, desired_state: {undetermined, true, false}}])`. All three boolean keys are required; `unevaluated` is **not** valid.
5. Seed with examples if available: if the user can name 5+ good-fit companies, `add_lead(list_id, company_url, ...)` for each. Otherwise `find_new_leads(list_id, limit=5)` (max 20) for starter candidates.
6. `get_leads_wait(list_id)` to block until the list settles (no searches, qualifier evals, or lead evals in progress). Default timeout 15 min — call again if it times out rather than treating it as fatal.

Then drop into the main loop.

## Iterating on qualifiers

The ICQ won't be perfect on the first pass. Watch for these signals:

- User **accepts** a lead that **failed** a qualifier → probably a misphrased qualifier. Ask "you accepted this even though X was false — should the qualifier change?"
- User **rejects** a lead that **passed** every qualifier → either adjust an existing qualifier or add a new one. Discuss with the user which.

After any qualifier change:

- **New or edited qualifier: verify on 10–20 leads before trusting it.** `bulk_evaluate_qualifier(pairs=[{lead_id, qualifier_id}, ...], force_refresh=true)` → `get_leads_wait` → sanity-check results with the user.
- Revisit qualifiers periodically — they can drift in quality as the lead mix changes.

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
- Both require the list to have an `email_generation_config_id` assigned.
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
