#get the good tar command depending of bash or macos
tarcmd=$(case "$(uname -s)" in Darwin)  echo 'gtar';;  Linux) echo 'tar';; esac)

#get the timestamp for file name
datestamp=$(date --utc +%Y-%m-%dT%H_%M_%S)
echo version will be stamped as : $datestamp

(
  # download tarball from VirusSeq
  wget -O data_needed/virusseq.$datestamp.tar.gz https://singularity.virusseq-dataportal.ca/download/archive/all  > /dev/null 2>&1
  # scan tarball for filenames
  tar -ztf data_needed/virusseq.tar.gz > .list_filenames$datestamp
  # stream metadata into gz-compressed file
  $tarcmd -axf data_needed/virusseq.$datestamp.tar.gz -O $(cat .list_filenames$datestamp | grep tsv$) | gzip > data_needed/virusseq.$datestamp.metadata.tsv.gz
  # stream FASTA data into xz-compressed file
  $tarcmd -axf data_needed/virusseq.$datestamp.tar.gz -O $(cat .list_filenames$datestamp | grep fasta$) | xz > data_needed/virusseq.$datestamp.fasta.xz
  # delete tarball
  rm data_needed/virusseq.$datestamp.tar.gz .list_filenames$datestamp
)&

(
  #get the json contain
  wget -O .temp https://raw.githubusercontent.com/cov-lineages/pango-designation/master/pango_designation/alias_key.json  > /dev/null 2>&1
  cat .temp | sed 's\[":,]\\g' | awk 'NF==2 && substr($1,1,1)!="X"{print "alias",$1,$2}' > data_needed/pango_designation_alias_key.json 
  
  #download pangolin calls from DNAstack and create a column with raw names (eg: BA.5 is B.1.1.529.5)
  dnastack collections query virusseq "SELECT isolate, lineage, pangolin_version FROM publisher_data.virusseq.samples" --format csv > data_needed/viralai.$datestamp.csv
  ( cat data_needed/pango_designation_alias_key.json;cat data_needed/viralai.$datestamp.csv | tr ',' ' ')|
    awk  '$1=="alias"{t[$2]=$3}$1!="alias"{rem=$2;split($2,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $2)}print $1,$2,rem,$3}' |
    tr ' ' ',' | sed 's/lineage,lineage/rawlineage,lineage/g'> data_needed/viralai.$datestamp.withalias.csv
  
  
  
  #get the fasta from ncov
  wget -O data_needed/ncov-open.$datestamp.fasta.xz https://data.nextstrain.org/files/ncov/open/sequences.fasta.xz  > /dev/null 2>&1
  
  #get the metadata from ncov and add a column with raw names (eg: BA.5 is B.1.1.529.5)
    wget -O data_needed/ncov-open.$datestamp.tsv.gz https://data.nextstrain.org/files/ncov/open/metadata.tsv.gz  > /dev/null 2>&1
    (
      cat data_needed/pango_designation_alias_key.json;
      zcat data_needed/ncov-open.$datestamp.tsv.gz | tr ' ' '_' | sed 's/\t\t/\tNA\t/g' | sed 's/\t\t/\tNA\t/g'| sed 's/\t$/\tNA/g'
      ) |
    awk  '$1=="tag"{t[$2]=$3}$1=="strain"{for(i=1;i<=NF;i++){if($i=="pango_lineage"){col=i;print $0,"rawlineage";next;}}}$1!="tag" && $1!="strain"{rem=$i;split($i,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $i)};raw=$i;$i=rem;print $0,raw}' |
    tr ' ' '\t'  | gzip > data_needed/ncov-open.$datestamp.withalias.tsv.gz
)&

wait $(jobs -p | tr '\n' ' ')


