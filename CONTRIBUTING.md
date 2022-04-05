# To set up a development/test environment

## Dependencies
* [Python 3.6+](https://www.python.org/downloads/)
* [R 4.0.2+](https://cran.r-project.org/)
* [miniconda](https://docs.conda.io/en/latest/miniconda.html)
* [Pangolin](https://github.com/cov-lineages/pangolin)
* [OpenMPI](https://www.open-mpi.org/)
* [mpi4py](https://mpi4py.readthedocs.io/en/stable/)
* [minimap2](https://github.com/lh3/minimap2)

## To obtain required data

Note `<datetime>` is a placeholder for the date and time associated with downloading VirusSeq data, *e.g.*, `2022-03-16T15:17:45`.

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `python3 virusseq.py` | downloads most recent data release from [VirusSeq database](https://virusseq-dataportal.ca/) | `virusseq.<datetime>.fasta.xz` and `virusseq.<datetime>.metadata.tsv.gz` | ~15 minutes |
| `conda activate pangolin` | activates conda environment for Pangolin | | fast |
| `mpirun -np 8 python3 mangolin.py virusseq.<datetime>.fasta.xz` | uses MPI environment to classify sequences in parallel | `magnolin.0.csv`, `mangolin.1.csv`, etc. | ~30 minutes |
| `conda deactivate` | revert to default user environment | | fast |
| `head -n1 mangolin.0.csv > combined.csv && tail -n+2 -q mangolin.*.csv >> combined.csv` | combines `mangolin.py` outputs into a single CSV | `combined.csv` | fast |
| `python3 scripts/pango2vseq.py virusseq.<datetime>.metadata.tsv.gz combined.csv virusseq.<datetime>.csv.gz` | append Pangolin classifications to VirusSeq metadata | `virusseq.<datetime>.csv.gz` | 10 seconds |
| `python3 scripts/alignment.py virusseq.<datetime>.fasta.xz virusseq.<datetime>.csv.gz sample.fasta` | downsample genomes, use `minimap2` to align pairwise to reference and write result to FASTA | `sample.fasta` | ~2 minutes |

Repeat `alignment.py` three times to generate replicate samples: `sample[123].fasta`

## To generate phylogenies (ML and time-scaled)

The following steps should be applied to all three replicates from the preceding stage.

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `iqtree2 -ninit 2 -n 2 -me 0.05 -nt 8 -s sample1.fasta -m GTR -ninit 10 -n 4` | Use COVID-version of IQ-TREE to reconstruct ML tree | File containing Newick tree string, `sample1.fasta.treefile` |  ~30 minutes each |
| `Rscript scripts/root2tip.R data_needed/sample1.iqtree.nwk data_needed/sample1.rtt.nwk data_needed/sample1.dates.tsv` | Root the ML tree using root-to-tip regression, prune tips with outlying sequences (±3 s.d. of molecular clock prediction) and export files for TreeTime | `sample1.rtt.nwk` and `sample1.dates.tsv` | ~20 minutes |
| `treetime --tree sample2.rtt.nwk --dates sample2.dates.tsv --clock-filter 0 --sequence-length 29903` | Generate time-scaled tree, allowing re-estimation of the root | Folder with `_treetime` suffix, containing `timetree.nexus` file | ~20 minutes |
| `python3 nex2nwk.py timetree.nexus sample1.timetree.nwk` | Converts NEXUS to Newick format, excluding comment fields from internal nodes | file containing Newick tree string, `sample1.timetree.nwk` | ~2 minutes |
