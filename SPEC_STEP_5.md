# SPEC — Step 5: Layout / Nav Polish

Parent document: [`SPEC.md`](./SPEC.md)  
UI language: [`SPEC_STEP_3.md`](./SPEC_STEP_3.md) (“finance workspace” theme + standards)  
Prior feature work: Steps 1–4.9 complete

Status: **Complete** (responsive chrome + cleanup green)

---

## Placement

**Step 5** runs after all account/CC feature work (through 4.9) and **before** Step 6 browser verification. The visual system already exists from the Step 3 UI refresh; this step **polishes and cleans** rather than redesigns.

Order: **… → 4.9 → 5 → 6 → 7**

---

## What Step 5 is

Tighten app chrome and responsive behavior so desktop and mobile viewports feel intentional:

1. **Nav / layout polish** — sticky header works on narrow screens; active states stay correct; optional light footer.
2. **Responsive filters** — filter toolbars stack cleanly; inputs are full-width on small screens; tables keep horizontal scroll without clipping primary actions.
3. **Density / spacing** — small consistency passes (header vs main padding, filter card vs table gap) without changing brand tokens.
4. **Dead code removal** — delete unused `hello_controller.js` (and any other unused Stimulus leftovers).
5. **Import UX hygiene** — light anti-double-submit on multipart import forms if easy (`data-turbo-submits-with` / disable button).
6. **Document** what remains for Step 6 (real-device / browser E2E), not try to replace it.

### Goals (concrete)

| # | Goal |
|---|------|
| 1 | Header: readable on ~375px width — logo + nav don’t collide; nav may scroll horizontally or wrap with consistent spacing |
| 2 | Optional: extract `nav_link` helper to DRY active-state classes in `application.html.erb` |
| 3 | Filter partials (`shared/account_transaction_filters`, `shared/credit_card_transaction_filters`): ensure single-column on xs, 2-col sm, 3-col lg; labels/inputs touch-friendly |
| 4 | Add shared CSS utilities only if repeated (e.g. `.filter-field`, `.app-nav-link`, `.app-footer`) — follow Tailwind v4 rule: **do not** `@apply` one custom component into another |
| 5 | Remove `app/javascript/controllers/hello_controller.js` |
| 6 | Import forms (`account_statements/new`, `credit_card_statements/new`): prevent accidental double post |
| 7 | Smoke integration assertion(s): home still links Accounts / Statements / Credit cards; optional assert `hello_controller` not in importmap pins if removed from disk |
| 8 | Write this step’s outcome into Status / What you get when done |

### Depends on

| Prerequisite | Why |
|--------------|-----|
| Step 3 UI refresh | Brand tokens + components already in `application.css` |
| Steps 4–4.9 | Filter pages and account/CC chrome exist to polish |

### Explicitly out of Step 5

| Out | Notes |
|-----|--------|
| New visual language / recolor | Finance-workspace theme stays |
| New features (auth, charts, edit txns) | Parent out of scope |
| Step 6 browser E2E with real BoA PDFs | Separate step |
| Mobile hamburger mega-menu | Optional later; horizontal scroll/wrap is enough for three nav links |
| Pagination redesign | Keep existing Previous/Next |
| Changing filter semantics | Behavior stays Step 4 |

---

## Current baseline (do not throw away)

Already in place from earlier steps:

- Sticky header, teal/slate theme, `btn-*`, `card-pad`, `data-table`, flash partial
- Nav: Accounts · Statements · Credit cards
- Filter forms outside Turbo Frame; `live_filter_controller.js`
- `data-table-wrap` with `overflow-x-auto`

Step 5 **extends** this.

---

## Planned deliverables

### Layout (`application.html.erb`)

- Improve small-screen header layout, e.g.:
  - Hide tagline under logo on `sm` breakpoint if it crowds nav
  - `nav` with `overflow-x-auto` / `flex-nowrap` or tidy wrap + `gap`
- Keep flash in `main`; ensure main bottom padding leaves room for optional footer
- Optional minimal footer: app name only (no marketing)

### Helper (optional but recommended)

```ruby
# ApplicationHelper
def nav_link(label, path, active: nil)
  # active classes: bg-brand-50 text-brand-800
  # inactive: text-slate-600 hover:bg-slate-100
end
```

Use for the three primary nav links so active-path logic isn’t duplicated.

### CSS (`application.css`)

Only if it reduces duplication:

| Class | Purpose |
|-------|---------|
| `.app-header` / `.app-nav` | Header/nav spacing |
| `.filter-grid` | `grid gap-3 sm:grid-cols-2 lg:grid-cols-3` |
| `.filter-input` | Shared border/padding for filter controls |
| `.app-footer` | Muted footer |

Do **not** invent a second button system.

### Filters

- Apply shared field classes to bank + CC filter partials
- Confirm clear-filters link doesn’t wrap awkwardly on mobile
- Ensure pagination + total footer remain usable on narrow viewports (stack if needed — `flex-wrap` already partly there)

### Cleanup

- Delete `hello_controller.js`
- Confirm importmap eager-load won’t reference a missing file (eager load from directory — removing the file is enough)

### Import forms

- `data: { turbo_submits_with: "Importing…" }` on submit or equivalent so double-clicks are less likely during long PDF parses

### Tests

| Case | Expectation |
|------|-------------|
| Home / layout | Nav links to `accounts_path`, `account_statements_path`, `credit_card_accounts_path` |
| Regression | Existing integration suite still green |
| Optional | Filter page HTML includes stacked grid classes |

No need for Capybara mobile viewport system tests in Step 5 unless already cheap; Step 6 owns real browser verification.

---

## Acceptance checklist (Step 5)

- [x] Header/nav usable at mobile width (~375px) and desktop  
- [x] Filter toolbars stack on small screens; tables scroll horizontally without breaking page chrome  
- [x] `hello_controller.js` removed  
- [x] Import submit double-click mitigated  
- [x] No new brand palette / redesign  
- [x] Full test suite green  
- [x] This SPEC updated to **Complete** with What you get  

---

## What you get

- Responsive header: stacks on small screens; tagline hidden on xs; horizontally scrollable nav chips
- DRY `nav_link` / `nav_section_active?` helpers (Accounts no longer false-positives on `/account_statements`)
- Shared `.filter-grid` / `.filter-input` / `.filter-label` on bank + CC filter bars
- Pagination stacks on mobile
- Import buttons show “Importing…” via `turbo_submits_with`
- Minimal footer; `hello_controller.js` deleted

---

## Areas of concern

### Don’t redo Step 3’s theme

The biggest failure mode is another visual rewrite. Treat tokens in `@theme` as frozen unless fixing a clear contrast/accessibility bug.

### Active nav false positives

`request.path.start_with?("/accounts")` must not mark Statements active (paths are `/accounts` vs `/account_statements` — already OK). Credit cards path should cover `/credit_card_accounts` and optionally `/credit_card_statements`. Keep that logic when extracting helpers.

### Filter focus + Turbo

Don’t move filter inputs inside the Turbo Frame while polishing. Focus-loss on typeahead was solved in Step 4 by keeping the form outside the frame.

### Long PDF imports

Disable-on-submit helps but won’t fix request timeouts (known Step 2/3 concern). Don’t block Step 5 on Solid Queue.

### Accessibility

Ensure nav links and filter controls keep visible focus rings (`focus-visible:outline` already on buttons). Don’t remove outline utilities while tidying.

### Step 6 boundary

Step 5 can spot-check with curl/devtools widths; **manual** PDF import + live typing on phone/desktop is Step 6.

---

## Parent SPEC touch-up

When implementing, change Implementation order line 5 to link here:

`5. Layout/nav polish ([SPEC_STEP_5.md](./SPEC_STEP_5.md))`

---

## Key files to touch

```
app/views/layouts/application.html.erb
app/helpers/application_helper.rb              # optional nav_link
app/assets/tailwind/application.css            # optional filter/nav utilities
app/views/shared/_account_transaction_filters.html.erb
app/views/shared/_credit_card_transaction_filters.html.erb
app/views/shared/_pagination.html.erb          # optional stack on mobile
app/views/account_statements/new.html.erb      # submit hygiene
app/views/credit_card_statements/new.html.erb
app/javascript/controllers/hello_controller.js # DELETE
SPEC_STEP_5.md
SPEC.md                                        # link step 5
```

---

## Implementation notes when coding starts

1. Remove `hello_controller.js` first (safe, tiny).  
2. Nav/helper + header responsive pass.  
3. Shared filter field classes on both filter partials.  
4. Import button submit hygiene.  
5. Run full test suite; mark this SPEC **Complete** with What you get.
