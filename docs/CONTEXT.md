# Self-Contained Context: North Sea PhyC Bloom-Proxy Validation

## Scientific Rationale

The CMEMS North-West Shelf `phyc` field is modelled total phytoplankton carbon produced by NEMO–ERSEM. It is neither a taxonomic observation nor a dedicated state variable for *Phaeocystis*, diatoms, dinoflagellates, coccolithophores, or pico/nanophytoplankton.

The scientifically defensible first question is therefore generic: does PhyC track independently observed total phytoplankton biomass blooms? A second, nested question asks whether that performance is stable when the observed bloom is dominated by different recurrent lifeforms. This distinction prevents generic biomass skill from being misreported as species skill.

## North Sea Bloom Regimes

The North Sea is not one homogeneous bloom system. Hydrography, depth, stratification, river influence, nutrients, and water clarity create different recurrent regimes. The working candidate lifeforms are:

- spring diatom assemblages, expected across many coastal and shelf regions;
- coastal *Phaeocystis*/haptophyte blooms, especially in the southern North Sea;
- summer or autumn dinoflagellate assemblages;
- coccolithophore blooms in suitable northern or stratified waters;
- pico- and nanophytoplankton dominance where flow cytometry, pigments, or size-resolved observations can resolve it.

These are candidates, not assumed confirmatory strata. Eligibility is determined from independent observation recurrence and data adequacy before PhyC performance is inspected.

## Why Multiple Monitoring Networks Are Necessary

No single observing system provides basin-wide, daily, taxon-resolved carbon biomass.

- High-frequency stations such as Helgoland Roads resolve bloom timing but represent one hydrographic setting.
- National monitoring networks provide broader environmental coverage but often sample monthly or seasonally.
- CPR provides exceptional basin-scale continuity but is size-selective and many phytoplankton taxa are semi-quantitative.
- Imaging systems characterize selected particle-size ranges and can omit small cells.
- microscopy counts provide taxonomic detail but cannot be summed across taxa of different cell size as a carbon proxy without biovolume conversion.
- chlorophyll is widely available but varies with photoacclimation and community composition and is not independent when it enters the model through ocean-colour assimilation.

02A uses these differences as a structured external-validation design. Agreement across independent methods is stronger evidence than high performance within one network.

## Reference-Variable Hierarchy

The preferred reference hierarchy is:

1. independently estimated total phytoplankton carbon;
2. total phytoplankton biovolume;
3. taxon-resolved counts plus defensible cell-volume and carbon conversion;
4. within-lifeform abundance for lifeform-specific bloom detection;
5. chlorophyll, pigments, CPR PCI, or derived occurrence products as secondary comparators.

A lower tier cannot silently replace a higher tier. Every result is labelled by reference tier and observation method.

## Total Bloom Versus Lifeform Dominance

`total_biomass_bloom_present` is the paper's primary outcome. Lifeform identity is an effect modifier used to test whether PhyC sensitivity depends on bloom composition.

Lifeform dominance is calculated only from carbon or biovolume shares. Cell counts are comparable within a taxon or a sufficiently homogeneous size class, but total diatom counts cannot be compared directly with total dinoflagellate or picophytoplankton counts to infer biomass dominance.

PhyC may detect a bloom dominated by a group; it cannot identify which group caused the signal. A taxonomic classification claim would require a different predictor and a separate paper.

## Analysis Unit and Independence

The hierarchy is:

`in-situ sample → station/subregion-time window → bloom event → year → monitoring network`

The primary unit is `North Sea subregion × analysis window`. Complete events or years define validation folds. Monitoring networks and hydrographic regions define external-transfer tests. Daily model rows matched to the same bloom do not constitute independent replicates.

## Observation-Only Event Construction

Reference events are constructed without viewing CMEMS PhyC or satellite prediction results. The event catalogue preserves:

- total carbon or biovolume trajectory;
- dominant and co-dominant lifeforms where resolvable;
- sampling effort and maximum gap;
- event start and end intervals rather than false daily precision;
- positive, negative, and unknown windows;
- monitoring method, size fraction, taxonomic resolution, and conversion uncertainty.

Monthly networks can validate concurrent state over a matching window but cannot establish daily onset or peak dates. Those timing questions belong elsewhere in Module 02.

## Assimilation Boundary

The reanalysis assimilates ocean-colour information. Satellite chlorophyll and model fields constrained by that information are therefore not independent reference observations. Primary validation uses in-situ taxon, biovolume, carbon, or independently analysed abundance data. Model–satellite agreement is treated as a dependency analysis.

## Interpretation Boundary

A `generic_pass` means that PhyC is a useful concurrent covariate for total North Sea phytoplankton bloom state at the tested scales. It does not mean that PhyC measures a species or lifeform.

A `conditional_pass` means that the proxy is valid only in named regimes. For example, success for diatom-dominated spring blooms combined with failure for *Phaeocystis* means PhyC cannot support downstream *Phaeocystis* onset, peak, or source reconstruction.

## Ownership Within Module 02

02A owns concurrent total-bloom proxy validation, observation-only annual recurrence, and lifeform-stratified PhyC performance. It does not own forecast onset, post-onset peak prediction, satellite timing, DOC–chlorophyll lag estimation, or source-field fusion.

02B–02E receive only the frozen *Phaeocystis*-relevant result from 02A, and only if that stratum independently passes. The broader diatom, dinoflagellate, coccolithophore, and pico/nano results remain publication content of 02A and are not additional outcomes for the other Module 02 papers.
