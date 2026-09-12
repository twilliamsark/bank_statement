# SPEC — Step 8.4.2: Jump to Any Pagination Page

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md)  
Prior: [`SPEC_STEP_8.4.1.md`](./SPEC_STEP_8.4.1.md)

Status: **Complete**

---

## Goal

On paginated **credit card transactions** lists and the **unreconciled transactions** list, let the user jump directly to any page (not only Previous / Next).

---

## Decisions

| Topic | Decision |
| ----- | -------- |
| Control | Dropdown of page numbers `1…total_pages` |
| Placement | Shared `_pagination` partial (covers account/statement CC txn pages + unreconciled) |
| Behavior | Changing the select navigates immediately via GET + Turbo Frame |
| Preserve filters | Keep existing query params (`date_from`, `category`, etc.) when jumping |

---

## Done when

- Pagination shows a page select when there is more than one page
- Selecting a page loads that page inside the correct Turbo Frame
- Works for CC transaction lists and unreconciled list
