#!/bin/bash -e


#set the endpoints for dnastack databases. Only required on first run. 
dnastack config set collections.url https://viral.ai/api/
dnastack config set drs.url https://viral.ai/

data_needed/download.sh ViralAi
datestamp=$(ls data_needed/virusseq.*fasta.xz | tail -1 | cut -d. -f2)

#removes the recombinants
python3 scripts/extractSequences.py --infile data_needed/virusseq.$datestamp.fasta.xz --metadata data_needed/virusseq.metadata.csv.gz --outfile data_needed/

scripts/makeTree.sh

Rscript -e "rmarkdown::render('duotang.Rmd',params=list())"