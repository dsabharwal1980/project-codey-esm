# Text for the four experience screens (PRD: customer experience requirement)

Plain, short, the same on every surface. `{…}` are filled by the tools.

## Approval screen
| Element | Text |
|---|---|
| Title | `{Create / Update} {what}` – e.g. "Update CPQ setting EnableCoreLogs", "Assign permission sets – Sales rep", "Run ESM admin jobs" |
| Badge | Waiting for approval |
| Figures | Changes · New · Updated |
| List title | What will change |
| Row | `{target}` · Before: `{before}` → After: `{after}` · badge `{Create / Update / Assign / Start / Load / Skip / Manual / Remove}` |
| Callout (production only) | Production org – This is a production org: the change needs your explicit confirmation for production. |
| Note | Nothing is saved until you approve. Every change is logged. |
| Buttons | **Approve** (sends "Approve – go ahead with "{title}" (preview token …)") · **Reject** (sends "Reject – do not make the change …") |

## Health check report
| Element | Text |
|---|---|
| Title | ESM settings health check |
| Subtitle | `{licence status}` · `{n}` CPQ settings read · Sandbox / Production org · scope `{scope}` |
| Badge | All OK / Warnings / Needs Fix |
| Figures | OK · Warning · Needs Fix |
| List title | Items to look at / All checks passed |
| Row | `{label}` – `{reason}` Current: `{value or (not set) / •••• (set)}` · Recommended: `{value}` · area · badge OK / Warning / Needs Fix |
| Row buttons | **Fix it** (sends the fix request – it starts a preview) · **Help** (opens the help article) |
| Note | Read-only check. A fix changes nothing until you approve its preview. |
| Buttons | **Fix all fixable items** · **Run again** |

## Progress tracker
| Element | Text |
|---|---|
| Title | ESM admin jobs / Quote member checks |
| Subtitle | `{CJ-…}` · started `{date time}` · `{current step}` |
| Badge | Queued / Running / Completed / Failed / Paused |
| Bar | `{n}`% done |
| Row | `{step}` – `{detail: Finished (n batches) / n of m members / Do this in CMT Administration: …}` · badge Completed / Running / Failed / Manual / Pending |
| Callout (failed) | Can resume – Finished work is kept. Resume restarts from `{step}` (preview + approval first). |
| Buttons | **Refresh** · **Resume** (failed or paused) · **Results file** (bulk checks) |

## Upgrade impact report
| Element | Text |
|---|---|
| Title | Upgrade impact – release `{release}` |
| Subtitle | `{n}` customized screens checked |
| Badge | Review before upgrading / Some changes / Low risk |
| Figures | High · Medium · Low |
| List title | Affected customized screens |
| Row | `{screen} v{n}` – `{what changed}` · customized: `{version n, author x, edited date}` · kind · suggested action · badge High / Medium / Low |
| Row button | **Suggest merged version** (sends "Suggest a combined version of … for my review (do not deploy)") |
| Callout (sample list) | Release list – Sample entries; load the official release change list before relying on this report. |
| Note | Report only: nothing is changed. A combined version is a suggestion for your review. |

## Errors (any screen)
Title "Could not complete the request", badge "Not done", the message, then **How to fix** (plain words) and **Next step**.
