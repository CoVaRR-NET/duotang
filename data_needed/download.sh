# download tarball from VirusSeq
wget -O virusseq.tar.gz https://singularity.virusseq-dataportal.ca/download/archive/all
#get the good tar command depending of bash or macos
tarcmd=$(case "$(uname -s)" in Darwin)  echo 'gtar';;  Linux) echo 'tar';; esac)
#get the timestamp for file name
datestamp=$(date --utc +%Y-%m-%dT%H_%M_%S)
# scan tarball for filenames
tar -ztf virusseq.tar.gz > .list_filenames
# stream FASTA data into xz-compressed file
$tarcmd -axf virusseq.tar.gz -O $(cat .list_filenames | grep fasta$) | xz > virusseq.$datestamp.fasta.xz
# stream metadata into gz-compressed file
$tarcmd -axf virusseq.tar.gz -O $(cat .list_filenames | grep tsv$) | gzip > virusseq.$datestamp.metadata.tsv.gz
# delete tarball
rm virusseq.tar.gz .list_filenames


