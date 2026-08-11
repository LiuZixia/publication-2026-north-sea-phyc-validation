# Pending Work

## Ordered Actions

1. **FIRST PRIORITY — Execute Stage 5 observation harmonization.** Build source-specific acquisition/parsing and harmonization paths for DS02, DS04, DS05, DS06, DS07, and DS16, with DS22 retained as conversion authority. Completion requires immutable registered inputs, preserved original fields, validated keys/units/quality flags, and reproducible interim tables.
2. **Audit identity and conversion feasibility.** Resolve provider-versus-aggregator overlap and document whether the five Tier C candidates can be converted using defensible taxon/life-stage/method mappings anchored to DS06/DS22. Completion requires data-level duplicate evidence and conversion eligibility records, not narrative assumptions.
3. **Freeze the remaining observation-only design inputs before Stage 6.** Obtain and register prospective target-season definitions, minimum observations, maximum allowable gaps, and the decision on whether an offshore central/northern spatial unit requires a protocol amendment. Completion requires machine-readable parameters and a dated rationale before outcomes are constructed.
4. **Reassess the Stage 4 gate from harmonized observations.** Calculate adequately sampled years, independent network support, event-count potential, and lifeform recurrence potential without PhyC. Completion requires an updated deterministic gate that either authorizes Stage 6 or records the specific failed criteria.

## Blockers and Missing Inputs

- Numeric target-season adequacy parameters are not prospectively specified: target seasons, minimum observations, and maximum gaps require a scientific decision before Stage 6.
- The two frozen hydrographic polygons cannot separately diagnose the anticipated offshore central/northern evidence gap; changing spatial units requires a prospective protocol amendment.
- Event counts and observed recurrence remain unavailable until Stage 5 harmonization and Stage 6 observation-only construction.
- Exact CMEMS product identifier, version, variable, depth, extraction, masking, and collocation metadata remain unfrozen; CMEMS acquisition is not authorized.
- Source access, licenses, schemas, and downloadable records for the six primary candidates must be confirmed through the scripted Stage 5 acquisition workflow.

## Known Warnings and Scientific Risks

- The Stage 4 gate is `conditional_proceed_to_stage5_harmonization`; primary validation feasibility is `not_yet_demonstrated`.
- Coverage-year counts are feasibility ceilings, not adequately sampled years, negative windows, or recurrence evidence.
- Stage 3 `eligible` means permitted to enter compatibility/design checks, not final inclusion.
- DS06 is the only Tier A direct-carbon anchor. The other five primary networks depend on scientifically defensible Tier C conversion and may fail after record-level audit.
- Daily validation is not a confirmatory candidate on current evidence. The primary window remains unresolved between `7_day` and `cadence_matched` pending adequacy and event auditing.
- Confirmatory lifeform strata are not frozen; Stage 4 contains only recurrence potential and protocol-defined reference routes.

## Deferred / Out of Scope

- Stage 6 outcomes, events, recurrence strata, and validation splits remain unauthorized.
- CMEMS PhyC acquisition, inspection, matching, tuning, and performance evaluation remain unauthorized.
- Dataset discovery is not being reopened merely because only six networks currently have a primary Stage 5 role; all 19 retained Stage 2 datasets remain represented in the provisional manifest.
