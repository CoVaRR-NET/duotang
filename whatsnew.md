Duotang update {updatedate}:  

Detailed changes:
## Duotang.html
- Updated to VirusSeq release Aug 24, about 1000 new sequences since last update.
- **REVIEW REQUESTED** for the following modifications:
- Updated the methodology section for the case count data sources, now hyperlinked to their respective data stores (Closes #255).
- Updated the population values used for case count selection plots. Now uses population estimates from the lastest quartely release (April 1, 2023) (Closes #256)
- Corrected the Y-axis scale for the molecular clock estimates (Thank you Art!) (Closes #257)
- Added an average global and VOC substitution rate estimate line to the molecular clock estimate (Closes #258, #259)
- Modified the selection on omicron and case count plots to show 'The Rest' lineage, which usually contains the reference lineage not previously shown.
- Resolves an issue where XBB descendants that are not named XBB.\* are present in the non-recombinant tree but not present in the XBB tree. (Closes #246)
- Added a check to remove selection plots with the edge case of having too sparse, but still enough, data that within the 120 day date range. i.e. Nova Scotia. (Closes #262)
- Fix an issue where lineage name resolution is incorrect for descents who are not named after a parent who is a descendant of XBB that are not named XBB. E.g. FL.1.5.1 resolves incorrectly to HN rather than FL.1.5.1
- Minor text edits (Closes #261)


