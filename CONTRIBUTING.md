# Contributing to *duotang*

*duotang* is a collaborative effort involving members of [CoVaRR-Net Pillar 6](https://covarrnet.ca/our-team/#pillar-6) (computational biology and modelling), but we welcome contributions from the SARS-CoV-2 research community as [pull requests from a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork).
All updates, modifications and feature additions to this project are subject to review by our partners in public health.
You should also review the Canadian VirusSeq Data Portal [data usage policy](https://virusseq-dataportal.ca/acknowledgements).

Resources (metadata, trees, mutation frequency tables) can be updated with new data releases from VirusSeq using the workflow described below.



# To set up a development/test environment

## Dependencies
* [Python 3.9+](https://www.python.org/downloads/)
* [R 4.0.2+](https://cran.r-project.org/)
   * [ape](https://cran.r-project.org/web/packages/ape/index.html)
   * [tidyr](https://cran.r-project.org/web/packages/tidyr/index.html)
   * [lubridate](https://cran.r-project.org/web/packages/lubridate/index.html)
   * [ggplot2](https://cran.r-project.org/web/packages/ggplot2/index.html)
   * [r2d3](https://cran.r-project.org/web/packages/r2d3/index.html)
   * [jsonlite](https://cran.r-project.org/web/packages/jsonlite/index.html)
   * [ggfree](https://github.com/ArtPoon/ggfree) (note this is the only package not available on CRAN - installation instructions are provided in its README document)
   * [bbmle](https://cran.r-project.org/web/packages/bbmle/index.html)
   * [HelpersMG](https://cran.r-project.org/web/packages/HelpersMG/index.html)
   * [dplyr](https://cran.r-project.org/web/packages/dplyr/index.html)
   * [DT](https://cran.r-project.org/web/packages/DT/index.html)
   * [shiny](https://cran.r-project.org/web/packages/shiny/index.html)
   * [reshape2](https://cran.r-project.org/web/packages/reshape2/index.html)
   * [tidyverse](https://cran.r-project.org/web/packages/tidyverse/index.html)
* [minimap2](https://github.com/lh3/minimap2)
* [IQTREE2](http://www.iqtree.org/) - COVID-19 release
* [TreeTime](https://github.com/neherlab/treetime)

The following are needed as part of the update script and should be installed via PIP in a virtual environment if Conda is not being used.
* [BioPython](https://pypi.org/project/biopython/)
* [dnastack](https://docs.viral.ai/analysis/)
* [Pandas](https://pypi.org/project/pandas/)
* [Selenium](https://pypi.org/project/selenium/)
* [Webdriver-Manager](https://pypi.org/project/webdriver-manager/)
* [pycrypto](https://pypi.org/project/pycrypto/)

## Conda Environment

These dependencies can also be installed from the environment.yaml using `conda env create -f conda-env.yaml`

# Automated update

The update script `update.sh` is available at the root of this repo. This script attempts to automate the data download, data processing, and knitting process of building CoVaRR-Net Duotang.

The conda environment can be created using the environment.yaml file at the root of this repo. If a duotang conda environment is available, run the following command at the root directory:
`update.sh`

If conda is not available, but dependencies are install via python virtual env, run the script with the `--noconda` flag and specify a venv that the script should load for the needed dependencies via `--venvpath`.
`update.sh --noconda --venvpath /path/to/duotang/venv`

If all dependencies are install system wide, use the `--noconda` flag only.
`update.sh --noconda`
Note: the script might throw unreasonable errors should a dependency be missing in this mode.

## Download Data Only
To download external data only (e.g. FASTA, metadata, etc.), use the `--downloadonly` flag. The above section dealing with flags for dependencies still apply.
`./update.sh --downloadonly [--noconda --venvpath /path/to/venv]`. 

Arguments can also be provided for custom build functions:
 * `-d|--date` String in format "YYYY-MM-DD". This will be the datestamped used throughout the build process (default: $CurrentUTCDate)
 * `-s|--source` String. The value can be `viralai` or `virusseq`, this will be the genomic datasource used (default: viralai).
 * `-o|--outdir` String. The output directory of all but the HTML files (default: ./data_needed). 
 * `-f|--scriptdir` String. The ABSOLUTE path to the scripts directory (default: ${PWD}/scripts).
 * `--overwrite` Flag for discarding current checkpoints and restart update from beginning
 * `--buildmain` Flag used to knit the RMD and push the changes to the main branch for publishing.
 * `--downloadonly` Flag used to download data only. Script will exit once all external resources had been downloaded. 
 * `--noconda` Flag used to run the update script without conda. Note: The dependencies should exist in $PATH and this script makes no attempt to ensure that they exist. 
 * `--venvpath` String. The ABSOLUTE path to the venv containing dependencies. Should be used with `--noconda`.
 * `--skipgsd` Flag used to skip the GSD metadata download. 
 * `--liststeps` Prints the available checkpoint steps in this script. You can use this for the `--gotostep` argument.
 * `--gotostep` Jumps to a checkpoint step in the script, specify it as '#StepName:'. You must include the # at beginning and : at end. Use `--liststeps` to see all the available checkpoints. 

# Step by step instruction to obtain data, and to generate phylogenies

## To obtain required data

Note `<datetime>` is a placeholder for the date and time associated with downloading VirusSeq data, *e.g.*, `2022-03-16T15:17:45`.

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `sh data_needed/download.sh <ViralAi>` |  download data release from VirusSeq (or ViralAI if argument is provided), separate and re-compress, download also also data from ncov viralai and add pango designations | `ncov-open.$datestamp.fasta.xz`     `viralai.$datestamp.withalias.csv` `virusseq.$datestamp.fasta.xz` `ncov-open.$datestamp.withalias.tsv.gz` `virusseq.$datestamp.metadata.tsv.gz` |  ~20 minutes |
| `datestamp=$(ls data_needed/virusseq.*fasta.xz \| tail -1 \| cut -d. -f2)` | set the `datestamp` variable | | 1 second |
| `python3 scripts/alignment.py data_needed/virusseq.$datestamp.fasta.xz data_needed/virusseq.metadata.csv.gz data_needed/ --samplenum 3 --reffile resources/NC_045512.fa` | downsample genomes, use `minimap2` to align pairwise to reference and write result to FASTA | `sample1.fasta` `sample2.fasta` `sample3.fasta` | ~2 minutes |


## To generate phylogenies (ML and time-scaled)

The following steps should be applied to all three replicates from the preceding stage.

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `for i in 1 2 3; do iqtree2 -ninit 2 -n 2 -me 0.05 -nt 8 -s data_needed/sample$i.fasta -m GTR -ninit 10 -n 4; done` | Use COVID-version of IQ-TREE to reconstruct ML tree | File containing Newick tree string, `sample[123].fasta.treefile` | ~3 hour |
| `for i in 1 2 3; do Rscript scripts/root2tip.R data_needed/sample$i.fasta.treefile data_needed/sample$i.rtt.nwk data_needed/sample$i.dates.tsv; done` | Root the ML tree using reference genome as "outgroup", fit root-to-tip regression, prune tips with outlying sequences (±4 s.d. of molecular clock prediction) and export files for TreeTime | `sample[123].rtt.nwk` and `sample[123].dates.tsv` | ~1 minute |
| `for i in 1 2 3; do treetime --tree data_needed/sample$i.rtt.nwk --dates data_needed/sample$i.dates.tsv --clock-filter 0 --sequence-length 29903 --keep-root --outdir data_needed/sample$i.treetime_dir ;done` | Generate time-scaled tree, allowing re-estimation of the root | Folder `data_needed/sample[123].treetime_dir`, containing `timetree.nexus` file | ~10 minutes |
| `for i in 1 2 3; do python3 scripts/nex2nwk.py data_needed/sample$i.treetime_dir/timetree.nexus data_needed/sample$i.timetree.nwk; done` | Converts NEXUS to Newick format, excluding comment fields from internal nodes | file containing Newick tree string, `sample[1]123].timetree.nwk` | ~5 minutes |

## To generate mutation plot ("raphgraph")

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `for i in 1 2 4 5; do python3 scripts/get-mutations.py --pango rawlineage data_needed/virusseq.$datestamp.fasta.xz B.1.1.529.$i data_needed/virusseq.metadata.csv.gz data_needed/raphgraph/canada-BA$i.var; ; done` | Generate a frequency table of nucleotides at all positions for Canadian genomes of user-specified lineage, aligned against the reference | `canada-BA1.var` | ~1 minute |
| `for i in 1 2 4 5; do python3 scripts/get-mutations.py --seqname strain --delimiter "\t" --pango rawlineage data_needed/ncov-open.$datestamp.fasta.xz B.1.1.529.$i data_needed/ncov-open.$datestamp.withalias.tsv.gz data_needed/raphgraph/global-BA$i.var ; done` | Generate the corresponding nucleotide frequency table for global data set | `global-BA1.var` |  |
