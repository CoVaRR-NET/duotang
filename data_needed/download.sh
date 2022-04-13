# download tarball from VirusSeq
#wget -O virusseq.tar.gz https://singularity.virusseq-dataportal.ca/download/archive/all
# scan tarball for filenames
filenames=$(gtar -ztf virusseq.tar.gz)
# stream FASTA data into xz-compressed file
gtar -axf virusseq.tar.gz -O $filenames[0] | xz > virusseq.fasta.xz
# stream metadata into gz-compressed file
gtar -axf virusseq.tar.gz -O $filenames[1] | gzip > virusseq.metadata.tsv.gz
# ? rm virusseq.tar.gz
