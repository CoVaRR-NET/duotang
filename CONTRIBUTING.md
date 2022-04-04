# To set up a development/test environment (obtain required data)

## Dependencies
* [Python 3.6+](https://www.python.org/downloads/)
* [R 4.0.2+](https://cran.r-project.org/)
* [miniconda](https://docs.conda.io/en/latest/miniconda.html)
* [Pangolin](https://github.com/cov-lineages/pangolin)
* [OpenMPI](https://www.open-mpi.org/)
* [mpi4py](https://mpi4py.readthedocs.io/en/stable/)

## Procedure

| Command | Description | Outputs | Expected time |
|---------|-------------|---------|---------------|
| `python3 virusseq.py` | downloads most recent data release from [VirusSeq database](https://virusseq-dataportal.ca/) | `virusseq.<timestamp>.fasta.xz` and `virusseq.<timestamp>.metadata.tsv.gz` | ~15 minutes |
| `conda activate pangolin` | activates conda environment for Pangolin | | fast |
| `mpirun -np 8 python3 mangolin.py virusseq.2022-03-16T15\:17\:45.fasta.xz` | uses MPI environment to classify sequences in parallel | `magnolin.0.csv`, `mangolin.1.csv`, etc. | ~30 minutes |

 
