#! /bin/bash -e
#get the good tar command depending of bash or macos
unamestr=$(uname -s)
if [[ "$unamestr" == "Darwin" ]]; then
   tarcmd='gtar'
elif [[ "$unamestr" == "Linux" ]]; then
   tarcmd='tar'
else
   echo "Unsupported OS"
fi
#tarcmd=$(case "$(uname -s)" in Darwin) echo 'gtar'; Linux echo 'tar'; esac)

#get the timestamp for file name
datestamp=$(date --utc +%Y-%m-%dT%H_%M_%S)
echo version will be stamped as : $datestamp

data_dir=${PWD}/data_needed
scripts_dir=${PWD}/scripts


#get the json containing aliases
wget -O ${data_dir}/alias_key.json https://raw.githubusercontent.com/cov-lineages/pango-designation/master/pango_designation/alias_key.json  #> /dev/null 2>&1
cat  ${data_dir}/alias_key.json | sed 's\[":]\\g' | awk 'NF==2{print $1,$2}' |  sed 's\[^A-Z0-9\.\/]\ \g' | awk '
   function fullname(s){split(s,ss,".");for(j=NR-1;j>0;j--){if(ss[1]==n[j]){gsub(ss[1],p[j],s);break}};return(s)}
   BEGIN{print "alias lineage"}
   NF==2{n[NR]=$1;p[NR]=$2}
   NF>2{
      root=fullname($2);
      for(i=3;i<=NF;i++){
         split(fullname($i),sf,".")
         split(root,sr,".")
         root=sf[1]
         k=2
         while(sf[k]==sr[k]){root=root"."sf[k];k++}
      }
      n[NR]=$1
      p[NR]=root"."$1
   }
   {print n[NR],p[NR]}
' | tr ' ' '\t' >  ${data_dir}/pango_designation_alias_key.tsv

#(
 #get the fasta from ncov
  wget -O ${data_dir}/ncov-open.$datestamp.fasta.xz https://data.nextstrain.org/files/ncov/open/sequences.fasta.xz  #> /dev/null 2>&1

  #get the metadata from ncov and add a column with raw names (eg: BA.5 is B.1.1.529.5)
    wget -O ${data_dir}/ncov-open.$datestamp.tsv.gz https://data.nextstrain.org/files/ncov/open/metadata.tsv.gz # > /dev/null 2>&1
    (
      cat ${data_dir}/pango_designation_alias_key.tsv;
      zcat ${data_dir}/ncov-open.$datestamp.tsv.gz | tr ' ' '_' | sed 's/\t\t/\tNA\t/g' | sed 's/\t\t/\tNA\t/g'| sed 's/\t$/\tNA/g'
      ) |
    awk  '$1=="alias"{t[$2]=$3;next;}$1=="strain"{for(i=1;i<=NF;i++){if($i=="pango_lineage"){col=i;print $0,"raw_lineage";next;}}}{rem=$i;split($i,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $i)};raw=$i;$i=rem;print $0,raw}' |
    tr ' ' '\t'  | gzip > ${data_dir}/ncov-open.$datestamp.withalias.tsv.gz
#)&


#(
  if [[ $1 == "ViralAi" ]]
  then
    echo "Data source is ViralAi"
    (
      python  ${scripts_dir}/viralai_fetch_metadata.py --alias ${data_dir}/pango_designation_alias_key.tsv --csv ${data_dir}/virusseq.metadata.csv.gz
    )
    (
      mkdir -p  ${data_dir}/temp
      python  ${scripts_dir}/viralai_fetch_fasta_url.py --seq ${data_dir}/temp/fasta_drl.$datestamp.txt
      dnastack files download -i  ${data_dir}/temp/fasta_drl.$datestamp.txt -o ${data_dir}/temp
      mv ${data_dir}/temp/*.xz ${data_dir}/virusseq.$datestamp.fasta.xz
      rm -r  ${data_dir}/temp
    )
    
  else
    (
      echo "Data source is VirusSeq"
      # download tarball from VirusSeq
      wget -O ${data_dir}/virusseq.$datestamp.tar.gz https://singularity.virusseq-dataportal.ca/download/archive/all # > /dev/null 2>&1
      # scan tarball for filenames
      tar -ztf ${data_dir}/virusseq.$datestamp.tar.gz > ${data_dir}/.list_filenames$datestamp
      # stream metadata into gz-compressed file
      $tarcmd -axf ${data_dir}/virusseq.$datestamp.tar.gz -O $(cat ${data_dir}/.list_filenames$datestamp | grep tsv$) | gzip > ${data_dir}/virusseq.$datestamp.metadata.tsv.gz
      # stream FASTA data into xz-compressed file
      $tarcmd -axf ${data_dir}/virusseq.$datestamp.tar.gz -O $(cat ${data_dir}/.list_filenames$datestamp | grep fasta$) | perl -p -e "s/\r//g" | xz -T0 > ${data_dir}/virusseq.$datestamp.fasta.xz
      # delete tarball
      rm ${data_dir}/virusseq.$datestamp.tar.gz ${data_dir}/.list_filenames$datestamp
      dnastack collections query virusseq "SELECT isolate, lineage, pangolin_version FROM collections.virusseq.samples" --format csv > ${data_dir}/viralai.$datestamp.csv
      (cat ${data_dir}/pango_designation_alias_key.tsv;cat ${data_dir}/viralai.$datestamp.csv | tr ',' ' ') | awk  '$1=="alias"{t[$2]=$3}$1!="alias"{rem=$2;split($2,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $2)}print $1,$2,rem,$3}' |
      tr ' ' ',' | sed 's/lineage,lineage/raw_lineage,lineage/g'> ${data_dir}/viralai.$datestamp.withalias.csv
      python3 scripts/pango2vseq.py ${data_dir}/virusseq.$datestamp.metadata.tsv.gz ${data_dir}/viralai.$datestamp.withalias.csv ${data_dir}/virusseq.metadata.csv.gz
    )
  fi

#)&


#fetch epidata from multiple sources, These link might change at any time, especially the ON and QC ones. 
wget -O ${data_dir}/AgeCaseCountBC.csv www.bccdc.ca/Health-Info-Site/Documents/BCCDC_COVID19_Dashboard_Case_Details.csv
wget -O ${data_dir}/AgeCaseCountAB.csv https://www.alberta.ca/data/stats/covid-19-alberta-statistics-data.csv
wget -O ${data_dir}/AgeCaseCountON.csv https://data.ontario.ca/datastore/dump/455fd63b-603d-4608-8216-7d8647f43350?bom=True
wget -O ${data_dir}/AgeCaseCountQC.csv https://www.inspq.qc.ca/sites/default/files/covid/donnees/covid19-hist.csv?randNum=27899648
wget -O ${data_dir}/AgeCaseCountSK.csv https://dashboard.saskatchewan.ca/export/cases/4565.csv
wget -O ${data_dir}/CanadianEpiData.csv https://health-infobase.canada.ca/src/data/covidLive/covid19-download.csv

#wait $(jobs -p | tr '\n' ' ')
