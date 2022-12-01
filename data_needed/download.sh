#get the good tar command depending of bash or macos
tarcmd=$(case "$(uname -s)" in Darwin)  echo 'gtar';;  Linux) echo 'tar';; esac)

#get the timestamp for file name
datestamp=$(date --utc +%Y-%m-%dT%H_%M_%S)
echo version will be stamped as : $datestamp

data_dir=${PWD}/${data_dir}
scripts_dir=${PWD}/scripts

#get the json containing aliases
wget -O ${data_dir}/alias_key.json https://raw.githubusercontent.com/cov-lineages/pango-designation/master/pango_designation/alias_key.json  > /dev/null 2>&1
cat  ${data_dir}/alias_key.json | sed 's\[":,]\\g' | awk 'NF==2 && substr($1,1,1)!="X"{print "alias",$1,$2}' >  ${data_dir}/pango_designation_alias_key.json

(
 #get the fasta from ncov
  wget -O ${data_dir}/ncov-open.$datestamp.fasta.xz https://data.nextstrain.org/files/ncov/open/sequences.fasta.xz  > /dev/null 2>&1

  #get the metadata from ncov and add a column with raw names (eg: BA.5 is B.1.1.529.5)
    wget -O ${data_dir}/ncov-open.$datestamp.tsv.gz https://data.nextstrain.org/files/ncov/open/metadata.tsv.gz  > /dev/null 2>&1
    (
      cat ${data_dir}/pango_designation_alias_key.json;
      zcat ${data_dir}/ncov-open.$datestamp.tsv.gz | tr ' ' '_' | sed 's/\t\t/\tNA\t/g' | sed 's/\t\t/\tNA\t/g'| sed 's/\t$/\tNA/g'
      ) |
    awk  '$1=="alias"{t[$2]=$3;next;}$1=="strain"{for(i=1;i<=NF;i++){if($i=="pango_lineage"){col=i;print $0,"raw_lineage";next;}}}{rem=$i;split($i,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $i)};raw=$i;$i=rem;print $0,raw}' |
    tr ' ' '\t'  | gzip > ${data_dir}/ncov-open.$datestamp.withalias.tsv.gz
)&


(
  if [[ $1 == "ViralAi" ]]
  then

          echo "Data source is ViralAi"
          cat  ${data_dir}/alias_key.json | sed 's\[":,]\\g' | awk 'NF==2 && substr($1,1,1)!="X"{print $1,$2}' |  tr ' ' \\t  >  ${data_dir}/pango_designation_alias_key_viralai.tsv
          sed -i '1i alias\tlineage'  ${data_dir}/pango_designation_alias_key_viralai.tsv
          rm  ${data_dir}/alias_key.json
          (
            python  ${scripts_dir}/viralai_fetch_metadata.py --alias ${data_dir}/pango_designation_alias_key_viralai.tsv --csv ${data_dir}/virusseq.metadata.csv.gz
          )
          (
            mkdir -p  ${data_dir}/temp
            python  ${scripts_dir}/viralai_fetch_fasta_url.py --seq ${data_dir}/temp/fasta_drl.$datestamp.txt
            dnastack files download -i  ${data_dir}/temp/fasta_drl.$datestamp.txt -o ${data_dir}/temp
            mv ${data_dir}/temp/*.fa ${data_dir}/virusseq.$datestamp.fasta && xz -T0 ${data_dir}/virusseq.$datestamp.fasta
            rm -r  ${data_dir}/temp
          )


  else
        (
          echo "Data source is VirusSeq"
          # download tarball from VirusSeq
          wget -O ${data_dir}/virusseq.$datestamp.tar.gz https://singularity.virusseq-dataportal.ca/download/archive/all  > /dev/null 2>&1
          # scan tarball for filenames
          tar -ztf ${data_dir}/virusseq.$datestamp.tar.gz > ${data_dir}/.list_filenames$datestamp
          # stream metadata into gz-compressed file
          $tarcmd -axf ${data_dir}/virusseq.$datestamp.tar.gz -O $(cat ${data_dir}/.list_filenames$datestamp | grep tsv$) | gzip > ${data_dir}/virusseq.$datestamp.metadata.tsv.gz
          # stream FASTA data into xz-compressed file
          $tarcmd -axf ${data_dir}/virusseq.$datestamp.tar.gz -O $(cat ${data_dir}/.list_filenames$datestamp | grep fasta$) | perl -p -e "s/\r//g" | xz -T0 > ${data_dir}/virusseq.$datestamp.fasta.xz
          # delete tarball
          rm ${data_dir}/virusseq.$datestamp.tar.gz ${data_dir}/.list_filenames$datestamp

          dnastack collections query virusseq "SELECT isolate, lineage, pangolin_version FROM collections.virusseq.public_samples" --format csv > ${data_dir}/viralai.$datestamp.csv
          ( cat ${data_dir}/pango_designation_alias_key.json;cat ${data_dir}/viralai.$datestamp.csv | tr ',' ' ') | awk  '$1=="alias"{t[$2]=$3}$1!="alias"{rem=$2;split($2,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $2)}print $1,$2,rem,$3}' |
          tr ' ' ',' | sed 's/lineage,lineage/raw_lineage,lineage/g'> ${data_dir}/viralai.$datestamp.withalias.csv
          python3 scripts/pango2vseq.py ${data_dir}/virusseq.$datestamp.metadata.tsv.gz ${data_dir}/viralai.$datestamp.withalias.csv ${data_dir}/virusseq.metadata.csv.gz
        )
  fi

)&

wait $(jobs -p | tr '\n' ' ')
