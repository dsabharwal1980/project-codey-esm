---
name: esm-bulk-members
description: Load many quote members from a spreadsheet and check addresses and serviceability in the background with progress, then return a results file with the reason for any failure. Use for "load these 4,000 sites onto this quote and check them".
triggers: ["load sites", "quote members", "address verification", "serviceability", "thousands of sites", "bulk check"]
tools: [check_quote_members_bulk, track_codey_job, get_codey_playbook]
cards: [Approval, Progress tracker]
runbooks: [US-08]
---

# Skill: Bulk members

**Purpose:** large deals not slowed down by site loading and checks (> 10,000 members supported).
**Example request:** "Load these 4,000 sites onto this quote and check them."

## Steps
1. **Check the spreadsheet** – `check_quote_members_bulk mode=preview quoteId=<quote> membersCsv=<rows>` (or
   `contentDocumentId=069…` for a file attached in Salesforce). The preview reports recognised columns, rows OK, rows with
   errors (missing street/city/postal code, bad country), and duplicates already on the quote. Show the Approval card.
2. **Load after approval** – `mode=commit previewToken=…` loads only valid, new rows (safe to run again).
3. **Check in the background** – the same commit (or `checks=address,serviceability` on an existing quote) starts the batch
   job; show the Progress tracker; poll with `track_codey_job jobId=…`. Batches respect platform limits; failed batches
   retry once; a stopped job resumes from its cursor.
4. **Results file** – when complete, the tool returns a CSV (member, address, address result, serviceable, technology,
   reason) attached to the quote. Summarise: valid / partial / invalid; serviceable / not serviceable; top reasons.

## Rules
- Member addresses stay in the org (results file is a Salesforce file on the quote).
- One bulk job per quote at a time.

## Result
`Loaded <n>, skipped <n> duplicates, <n> errors. Address: <valid>/<partial>/<invalid>. Serviceable: <n>. Results file: <name>.`
