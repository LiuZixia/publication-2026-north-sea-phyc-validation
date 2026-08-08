# Pending

- **Updated (UTC):** 2026-08-08T11:05:00Z
- **Current stage:** Stage 2: Target Data Qualification. Do not begin CMEMS acquisition or PhyC inspection.

## Current Audit

Stage 1 remediation is complete. Stage 1 validation fully passed.

## First Priority

**Freeze the Stage 2 acquisition/licensing plan and record-level screening contract, beginning with DS06 SMHI SHARK.**

Completion evidence:
- A completed and approved plan for Stage 2 execution.
- Automated tests covering Stage 2 logic.

## Ordered Next Actions

1. Review and freeze DS06 SMHI SHARK metadata and access requirements.
2. Review remaining candidate datasets for record-level screening logic.
3. Draft the Stage 2 pipeline steps for data qualification.

## Blockers, Warnings, and Scientific Risks

- DS08 moratorium/licence terms remain unresolved; no provider response or permission is recorded.
- The 7,919 `pending` catalogue rows are neither eligible nor independent datasets.
- GBIF lacks a spatial dataset filter; geographic screening remains necessary during qualification.
- DOME and aggregator records may duplicate national sources.
- DS22 North Sea taxon coverage and coefficient applicability still require audit.
- Abandoned preflight raw runs are immutable, excluded by the active-run registry, and must not be reused silently.

## Deferred or Out of Scope

- Do not inspect CMEMS PhyC until the eligible in-situ manifest, observation-only outcomes, recurrence labels, and validation splits are frozen.
- Do not interpret search yield or known-item recall as biological eligibility, data usability, independence, or feasibility.
- Do not begin event construction, modelling, or performance analysis during Stage 2.
- Do not treat the passing automated validation as proof that untested Stage 1 requirements are satisfied.
