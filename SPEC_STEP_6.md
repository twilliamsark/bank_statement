# SPEC — Step 6: Browser Verification (Real Documents Samples)

Parent document: [`SPEC.md`](./SPEC.md)  
Prior: Steps 1–5 complete (through layout polish)

Status: **Complete** (manual verification by user)

---

## What Step 6 is

End-to-end **browser** checks with real BoA files (not only automated CSV fixtures):

1. Import bank PDF/CSV and CC PDF/CSV from local Documents samples when present  
2. Confirm statement/account/CC summaries and drill into transactions  
3. Exercise date / type / description / amount filters (live typing)  
4. Re-import the same file → skipped-duplicate counts; first import of a file with duplicate lines stores both  
5. Spot-check mobile viewport on filter pages  
6. Cover bank **account** master + summary and CC **account** master + summary (4.5–4.9)

### Sample files (names only; not committed)

| Flow | Example filename |
|------|------------------|
| Bank account PDF | `BoA_Savings_Jan_2026.pdf` |
| Bank account CSV | e.g. `BoA_InterestCheck_Jan_2026.csv` or gem-written CSV |
| CC year-end PDF | `BoA_CC_YearEndSummary_2025.pdf` |
| CC year-end CSV | matching year-end CSV if present |

Typical path: `~/Documents/<filename>`.

---

## Acceptance checklist

- [x] Manual browser verification performed (user-reported)  
- [x] Real Documents samples used as available  
- [x] No separate automated Step 6 suite required  

### Intended coverage (for the record)

- [x] Bank PDF and/or CSV import → summary → transactions → filters  
- [x] CC PDF and/or CSV import (with named card) → summary → master txns → filters  
- [x] Account-level bank summary / master transactions  
- [x] Re-import / duplicate-skip behavior observed as applicable  
- [x] Responsive / mobile spot-check as applicable  

---

## What you get

- Product flows through 4.9 + Step 5 chrome validated in a real browser by the user  
- Step 7 can focus on any remaining suite/cleanup unless new defects are filed  

---

## Findings

None recorded at completion time. If issues turn up later, add them here or under Step 7.

---

## Notes

- Step 6 was executed **manually** (not by the agent / not via MCP browser tools).  
- Binaries remain outside the repo; only filenames are documented.
