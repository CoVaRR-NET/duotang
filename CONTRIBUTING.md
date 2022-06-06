# Contributing to *duotang*

*duotang* is a collaborative effort involving members of [CoVaRR-Net Pillar 6](https://covarrnet.ca/our-team/#pillar-6) (computational biology and modelling), but we welcome contributions from the SARS-CoV-2 research community as [pull requests from a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork).
All updates, modifications and feature additions to this project are subject to review by our partners in public health.
You should also review the Canadian VirusSeq Data Portal [data usage policy](https://virusseq-dataportal.ca/acknowledgements).

Resources (metadata, trees, mutation frequency tables) can be updated with new data releases from VirusSeq using the workflow described below.



# To set up a development/test environment

## Dependencies
* [Python 3.6+](https://www.python.org/downloads/)
  * [BioPython](https://biopython.org/)
* [R 4.0.2+](https://cran.r-project.org/)
  * [ape](https://cran.r-project.org/web/packages/ape/index.html)
* [miniconda](https://docs.conda.io/en/latest/miniconda.html)
* [Pangolin](https://github.com/cov-lineages/pangolin)
* [OpenMPI](https://www.open-mpi.org/)
* [mpi4py](https://mpi4py.readthedocs.io/en/stable/)
* [minimap2](https://github.com/lh3/minimap2)
* [IQTREE2](http://www.iqtree.org/) - COVID-19 release
* [TreeTime](https://github.com/neherlab/treetime)

## To obtain required data

Note `<datetime>` is a placeholder for the date and time associated with downloading VirusSeq data, *e.g.*, `2022-03-16T15:17:45`.

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `cd data_needed` | change directories |  |  |
| `bash download.sh` | download data release from VirusSeq, separate and re-compress | `virusseq.fasta.xz`, `virusseq.metadata.tsv.gz` | 10 minutes |
| `dnastack collections query virusseq "SELECT isolate, lineage FROM publisher_data.virusseq.samples" --format csv > viralai.csv` | retrieve PANGO lineage classifications from Viral AI database | 1 minute |
| `cd ..` | back up to parent directory |  |  |
| `python3 scripts/pango2vseq.py data_needed/virusseq.<datetime>.metadata.tsv.gz data_needed/viralai.csv data_needed/virusseq.metadata.csv.gz` | append PANGO lineages to VirusSeq metadata | `virusseq.csv.gz` | 10 seconds |
| `for i in 1 2 3; do python3 scripts/alignment.py data_needed/virusseq.<datetime>.fasta.xz data_needed/virusseq.metadata.csv.gz data_needed/sample$i.fasta; done` | downsample genomes, use `minimap2` to align pairwise to reference and write result to FASTA | `sample.fasta` | ~2 minutes |


## To generate phylogenies (ML and time-scaled)

The following steps should be applied to all three replicates from the preceding stage.

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `iqtree2 -ninit 2 -n 2 -me 0.05 -nt 8 -s data_needed/sample1.fasta -m GTR -ninit 10 -n 4` | Use COVID-version of IQ-TREE to reconstruct ML tree | File containing Newick tree string, `sample1.fasta.treefile` | ~1 hour each |
| `Rscript scripts/root2tip.R data_needed/sample1.fasta.treefile data_needed/sample1.rtt.nwk data_needed/sample1.dates.tsv` | Root the ML tree using reference genome as "outgroup", fit root-to-tip regression, prune tips with outlying sequences (±4 s.d. of molecular clock prediction) and export files for TreeTime | `sample1.rtt.nwk` and `sample1.dates.tsv` | ~1 minute |
| `treetime --tree data_needed/sample2.rtt.nwk --dates data_needed/sample2.dates.tsv --clock-filter 0 --sequence-length 29903 --keep-root` | Generate time-scaled tree, allowing re-estimation of the root | Folder with `_treetime` suffix, containing `timetree.nexus` file | ~10 minutes |
| `python3 scripts/nex2nwk.py data_needed/2022-04-04_treetime/timetree.nexus data_needed/sample1.timetree.nwk` | Converts NEXUS to Newick format, excluding comment fields from internal nodes | file containing Newick tree string, `sample1.timetree.nwk` | ~5 minutes |

## To generate mutation plot ("raphgraph")

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `wget -O data_needed/ncov-open.2022-05-12.fasta.xz https://data.nextstrain.org/files/ncov/open/sequences.fasta.xz` | retrieve Genbank sequences from NextStrain (about 1GB) | xz-compressed FASTA file | ~2 minutes |
| `wget -O data_needed/ncov-open.2022-05-12.tsv.gz https://data.nextstrain.org/files/ncov/open/metadata.tsv.gz` | retrieve Genbank metadata from NextStrain (about 500 MB) | gzip-compressed TSV file | ~1 minute |
| `python3 scripts/get-mutations.py data_needed/virusseq.fasta.xz BA.1 data_needed/virusseq.metadata.csv.gz data_needed/raphgraph/canada-BA1.var` | Generate a frequency table of nucleotides at all positions for Canadian genomes of user-specified lineage, aligned against the reference | `canada-BA1.var` | ~1 minute |
| `python3 scripts/get-mutations.py --seqname strain --delimiter "\t" --pango pango_lineage data_needed/ncov-open.2022-05-12.fasta.xz BA.1 data_needed/ncov-open.2022-05-12.tsv.gz data_needed/raphgraph/global-BA1.var` | Generate the corresponding nucleotide frequency table for global data set | `global-BA1.var` |  |
