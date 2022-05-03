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
| `bash download.sh` | download data release from VirusSeq, separate and re-compress | `virusseq.fasta.xz`, `virusseq.metadata.tsv.gz` | 10 minutes |
| `conda activate pangolin` | activates conda environment for Pangolin | | fast |
| `mpirun -np 2 python3 mangolin.py virusseq.<datetime>.fasta.xz` | uses MPI environment to classify sequences in parallel - note each process consumes about 10GB RAM! | `magnolin.0.csv`, `mangolin.1.csv`, etc. | 1.5 hours |
| `conda deactivate` | revert to default user environment | | fast |
| `head -n1 mangolin.0.csv > combined.csv && tail -n+2 -q mangolin.*.csv >> combined.csv` | combines `mangolin.py` outputs into a single CSV | `combined.csv` | fast |
| `python3 scripts/pango2vseq.py virusseq.<datetime>.metadata.tsv.gz combined.csv virusseq.<datetime>.csv.gz` | append Pangolin classifications to VirusSeq metadata | `virusseq.<datetime>.csv.gz` | 10 seconds |
| `python3 scripts/alignment.py virusseq.<datetime>.fasta.xz virusseq.<datetime>.csv.gz sample.fasta` | downsample genomes, use `minimap2` to align pairwise to reference and write result to FASTA | `sample.fasta` | ~2 minutes |

Repeat `alignment.py` three times to generate replicate samples: `sample[123].fasta`

## To generate phylogenies (ML and time-scaled)

The following steps should be applied to all three replicates from the preceding stage.

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `iqtree2 -ninit 2 -n 2 -me 0.05 -nt 8 -s data_needed/sample1.fasta -m GTR -ninit 10 -n 4` | Use COVID-version of IQ-TREE to reconstruct ML tree | File containing Newick tree string, `sample1.fasta.treefile` | ~1 hour each |
| `Rscript scripts/root2tip.R data_needed/sample1.fasta.treefile data_needed/sample1.rtt.nwk data_needed/sample1.dates.tsv` | Root the ML tree using reference genome as "outgroup", fit root-to-tip regression, prune tips with outlying sequences (±4 s.d. of molecular clock prediction) and export files for TreeTime | `sample1.rtt.nwk` and `sample1.dates.tsv` | ~1 minute |
| `treetime --tree data_needed/sample2.rtt.nwk --dates data_needed/sample2.dates.tsv --clock-filter 0 --sequence-length 29903 --keep-root` | Generate time-scaled tree, allowing re-estimation of the root | Folder with `_treetime` suffix, containing `timetree.nexus` file | ~10 minutes |
| `python3 scripts/nex2nwk.py data_needed/2022-04-04_treetime/timetree.nexus data_needed/sample1.timetree.nwk` | Converts NEXUS to Newick format, excluding comment fields from internal nodes | file containing Newick tree string, `sample1.timetree.nwk` | ~5 minutes |
