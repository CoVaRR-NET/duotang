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
| `mpirun -np 8 python3 mangolin.py virusseq.2022-03-16T15\:17\:45.fasta.xz` | uses MPI environment to classify sequences in parallel | `magnolin.0.csv`, `mangolin.1.csv`, etc. | ~30 minutes |
| `conda deactivate` | revert to default user environment | | fast |
| `head -n1 mangolin.0.csv > combined.csv && tail -n+2 -q mangolin.*.csv >> combined.csv` | combines `mangolin.py` outputs into a single CSV | `combined.csv` | fast |
| `python3 scripts/pango2vseq.py virusseq.<datetime>.metadata.tsv.gz combined.csv virusseq.<datetime>.csv.gz` | append Pangolin classifications to VirusSeq metadata | `virusseq.<datetime>.csv.gz` | 10 seconds |
| `python3 scripts/alignment virusseq.<datetime>.fasta.xz virusseq.<datetime>.csv.gz sample.fasta` | downsample genomes, use `minimap2` to align pairwise to reference and write result to FASTA | `sample.fasta` | ~2 minutes |

## To generate phylogenies (ML and time-scaled)

