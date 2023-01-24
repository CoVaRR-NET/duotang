#!bin/bash -e


for i in 1 2 3; do 
	python3 scripts/alignment.py data_needed/Sequences_remainder.fasta.xz data_needed/SequenceMetadata_remainder.tsv.gz data_needed/sample$i.fasta; 
done
#recombinants only alignment, probably dont need to sample it.
python3 scripts/alignment.py data_needed/Sequences_matched.fasta.xz data_needed/SequenceMetadata_matched.tsv.gz data_needed/sample4.fasta --nosample; 


for i in 1 2 3 4; do 
	iqtree2 -ninit 2 -n 2 -me 0.05 -nt 8 -s data_needed/sample$i.fasta -m GTR -ninit 10 -n 4; 
done

for i in 1 2 3 4; do Rscript scripts/root2tip.R data_needed/sample$i.fasta.treefile data_needed/sample$i.rtt.nwk data_needed/sample$i.dates.tsv; done

for i in 1 2 3 4; do treetime --tree data_needed/sample$i.rtt.nwk --dates data_needed/sample$i.dates.tsv --clock-filter 0 --sequence-length 29903 --keep-root --outdir data_needed/sample$i.treetime_dir ;done

for i in 1 2 3 4; do python3 scripts/nex2nwk.py data_needed/sample$i.treetime_dir/timetree.nexus data_needed/sample$i.timetree.nwk; done
