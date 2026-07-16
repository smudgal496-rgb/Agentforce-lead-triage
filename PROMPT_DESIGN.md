# Prompt Design — Lead AI Triage

This document tracks the actual design decisions behind the prompt used in `LeadTriageAction.buildPrompt()`, including what changed and why.

## Goal

Given a Lead record's Company, Industry, Lead Source, and Description, have the model return a structured triage decision — a priority tier and a short rationale — that gets written directly back to the record without any manual parsing or cleanup.

## Design constraints

- **Output must be machine-parseable.** This isn't a chat interface; the response gets deserialized directly into Apex fields. Free-form prose output would require fragile string-matching to extract a priority level, so the model is forced into strict JSON.
- **Output must be short.** Long-form reasoning is wasted here — the rationale is a one-line field on a Lead record, not a report. Capping it forces the model to commit to a specific, defensible judgment instead of hedging.
- **Output must be honest under weak signal.** Real sales data is often sparse — a Lead with no Description or a one-line note is common, not an edge case. The prompt needed to produce a defensible "Cold" or "low confidence" result on thin data rather than confabulate false urgency.

## Final prompt

```
You are a sales lead triage assistant. Given the lead details below,
return ONLY valid JSON with keys "priority" (Hot, Warm, or Cold) and
"rationale" (max 20 words). No markdown, no explanation, just the JSON object.

Company: {company}
Industry: {industry}
Lead Source: {leadSource}
Description: {description}
```

## Iteration notes

**v1 — unstructured, free-text ask.** Early testing (manual prompts in AI Studio, not yet wired into Apex) asked the model to "assess this lead and suggest next steps" without format constraints. Output was reasonable but inconsistent in structure — sometimes a paragraph, sometimes a bulleted list — which would have required a fragile regex-based parser in Apex. Discarded in favor of forcing structured output before writing any integration code.

**v2 — JSON-forced, unconstrained length.** Adding `"return ONLY valid JSON"` fixed the parsing problem, but early rationale outputs ran 40–60 words — too long for the `AI_Rationale__c` field's practical display width in the Lead layout, and out of proportion to what a triage note should be.

**v3 (final) — JSON-forced, 20-word cap.** Adding an explicit word limit to the rationale key produces terse, sales-legible one-liners without materially reducing decision quality — the model still names the specific signal driving the score (company size, explicit demo request, or absence of both) rather than defaulting to generic language.

## Observed behavior worth noting

Two real test runs illustrate the model behaving as intended rather than just returning plausible-sounding text:

- **Sparse input → Cold, correctly.** A test Lead with only a Company name and a one-line Description ("Early-stage company, browsing pricing page, no direct contact yet") was scored **Cold**, with a rationale explicitly citing the lack of qualifying signal — not a confident but unjustified guess.
- **Strong input → Hot, correctly.** A test Lead with an enterprise company name, explicit demo request, and employee count above 500 was scored **Hot**, citing those exact signals.

This matters more than it might look: a model that defaults to optimistic scoring regardless of input quality would be actively harmful in a real sales workflow (wasted rep time chasing false positives). The prompt's insistence on citing a concrete signal in the rationale appears to discourage that failure mode, though this is based on a small number of manual test runs, not a systematic eval — worth flagging as a limitation, not a proven guarantee.

## Known limitation

The rationale is generated fresh on every run with no memory of prior triage decisions for the same Lead — if a Lead is re-triaged after a field update, the new rationale may contradict the old one with no audit trail beyond `AI_Last_Run__c`'s timestamp. A production version would likely want a history object logging each triage decision, not just the latest one overwriting the last.

## Model and provider note

This was originally built and tested against Claude (Anthropic), then migrated to Google's Gemini API (`gemini-3-flash-preview`) partway through development — a practical infrastructure decision (free tier vs. billing setup) rather than a prompt-design one. The prompt itself required no changes across the migration; only the request/response JSON shape in the Apex service layer changed. This turned out to be a reasonable small proof point that the prompt design is provider-agnostic rather than tuned to one model's quirks.
