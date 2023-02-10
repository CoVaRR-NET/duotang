#!/bin/bash -e
####################BIG BOLDED WARNING MESSAGE######################
#  This script contains onErrorResume functionality.               # 
#  Labels for these goto function start with '#' and end with ':'  #
#  For example: "#LabelName:", "#datalabel:"						   #
#  They must be the same as content of the checkpoint file         #
#  THEY ARE NOT COMMENTS, DO NOT DELETE THEM.					   #
####################################################################

# None of the arguments are required, defaults are set for all of them if they are not provided.
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--date)
      DATE="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--source)
      SOURCE="$2"
      shift # past argument
      shift # past value
      ;;
	-o|--outdir)
      data_dir="$2"
      shift # past argument
      shift # past value
      ;;
  	-f|--scriptdir)
      scripts_dir="$2"
      shift # past argument
      shift # past value
      ;;
    --overwrite)
      OVERWRITE="YES"
      shift # past argument
      ;;
	--clean)
      CLEAN="YES"
      shift # past argument
      ;;
	--buildmain)
      BUILDMAIN="YES"
      shift # past argument
      ;;
	--noconda)
      NOCONDA="YES"
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 2
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

checkPointFile=$PWD/checkpoint
restartedFromCheckpoint="false"

if [ -z "$DATE" ]; then DATE=`date --utc +%F`; fi
if [ -z "$SOURCE" ]; then SOURCE="viralai"; fi
if [ -z "$data_dir" ]; then data_dir="data_needed"; fi
if [ -z "$scripts_dir" ]; then scripts_dir="scripts"; fi
if [ "$OVERWRITE" = "YES" ]; then rm $checkPointFile; else OVERWRITE="NO"; fi
if [ "$BUILDMAIN" = "YES" ]; then BUILDMAIN="YES"; else BUILDMAIN="NO"; fi
if [ "$CLEAN" = "YES" ]; then CLEAN="YES"; else CLEAN="NO"; fi

if [ "$NOCONDA" = "YES" ]; then 
	NOCONDA="YES"; 
else 
	if [[ -n $(which conda) ]]; then 
		NOCONDA="NO"; 
	else 
		echo "Conda not found, make sure conda is in $PATH or use the --noconda flag"
		exit 1
	fi
fi

echo "Datestamp used: ${DATE}"
echo "Date source: ${SOURCE}"
echo "Data will be written to: ${data_dir}"
echo "Script folder located at: ${scripts_dir}"
echo "Overwrite checkpoints: ${OVERWRITE}"
echo "Main branch build mode: ${BUILDMAIN}"
echo "Clean up mode: ${BUILDMAIN}"
echo "Not using Conda?: ${NOCONDA}"

datestamp=$DATE

#function as a hack for labels and goto statements.
#labels start with '#' and end with ':' to avoid syntax errors. e.g. "#LabelName:"
function jumpTo ()
{
    label=$1    
    cmd=$(sed -n "/#$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    #echo "$cmd"
    eval "$cmd"
    exit
}

if [ "$BUILDMAIN" = "YES" ]; then 
	eval "$(conda shell.bash hook)"
	conda activate duotang
	jumpTo treecleaned 
fi
if [ "$CLEAN" = "YES" ]; then 
	eval "$(conda shell.bash hook)"
	conda activate duotang
	jumpTo cleanup
fi

#checkpoint logics
if [ -f $checkPointFile ]; then
	if [ "$NOCONDA" = "NO" ]; then 
		eval "$(conda shell.bash hook)"
		conda activate duotang
	fi
    echo "checkpoint file found..."
    step=`cat $checkPointFile`;
    #echo $step
    if [ $step = "finish" ]; then
        echo "A previous data download finished without error, delete the checkpoint file to overwrite the data, or use the --overwrite flag. exiting"
        exit 0
    else
        echo "attempting to restart workflow from $step"
        restartedFromCheckpoint="true"
        jumpTo $step
    fi
else
    #no checkpoint, start fresh
	if [ "$NOCONDA" = "NO" ]; then 
		eval "$(conda shell.bash hook)"
		conda activate duotang
	fi
    jumpTo begin
fi


#begin:
echo "begin" > $checkPointFile

#get the timestamp for file name
echo version will be stamped as : $datestamp

#get the json containing aliases
wget -O ${data_dir}/alias_key.json https://raw.githubusercontent.com/cov-lineages/pango-designation/master/pango_designation/alias_key.json  #> /dev/null 2>&1
cat  ${data_dir}/alias_key.json | sed 's\[":,]\\g' | awk 'NF==2 && substr($1,1,1)!="X"{print "alias",$1,$2}' >  ${data_dir}/pango_designation_alias_key.json
echo "alias" > $checkPointFile
#alias:

#get the fasta from ncov
wget -O ${data_dir}/ncov-open.$datestamp.fasta.xz https://data.nextstrain.org/files/ncov/open/sequences.fasta.xz  #> /dev/null 2>&1
echo "ncovfasta" > $checkPointFile
#ncovfasta:

wget -O ${data_dir}/ncov-open.$datestamp.tsv.gz https://data.nextstrain.org/files/ncov/open/metadata.tsv.gz # > /dev/null 2>&1
echo "ncovmetadata" > $checkPointFile
#ncovmetadata:

(cat ${data_dir}/pango_designation_alias_key.json;
zcat ${data_dir}/ncov-open.$datestamp.tsv.gz | tr ' ' '_' | sed 's/\t\t/\tNA\t/g' | sed 's/\t\t/\tNA\t/g'| sed 's/\t$/\tNA/g')|
awk  '$1=="alias"{t[$2]=$3;next;}$1=="strain"{for(i=1;i<=NF;i++){if($i=="pango_lineage"){col=i;print $0,"raw_lineage";next;}}}{rem=$i;split($i,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $i)};raw=$i;$i=rem;print $0,raw}' |
tr ' ' '\t'  | gzip > ${data_dir}/ncov-open.$datestamp.withalias.tsv.gz
echo "ncovclean" > $checkPointFile
#ncovclean:

if [[ $SOURCE == "viralai" ]]; then
	#set the endpoints for dnastack databases. Only required on first run. 
	dnastack config set collections.url https://viral.ai/api/
	dnastack config set drs.url https://viral.ai/

	echo "Data source is ViralAi"
	cat  ${data_dir}/alias_key.json | sed 's\[":,]\\g' | awk 'NF==2 && substr($1,1,1)!="X"{print $1,$2}' |  tr ' ' \\t  >  ${data_dir}/pango_designation_alias_key_viralai1.tsv
	cat ${data_dir}/pango_designation_alias_key_viralai.tsv ${data_dir}/alias_key.json | awk 'NF==2 && substr($1,1,1)!="\""{dico[$1]=$2}NF==2 && substr($1,1,2)=="\"X"{split(substr($2,1,length($2)-1),t,",");for(i in t){split(t[i],tt,"\"");e=split(tt[2],ttt,".");res=ttt[1];if(res in dico){res=dico[res]};for (j=2; j<=e;j++){res=res"."ttt[j]};t[i]=res}alias=substr($1,2,length($1)-3);printf alias" ";for(i in t){printf "%s ",t[i]}print " "}' | awk '{r=$2;for(i=3;i<=NF;i++){l=split(r,t1,".");split($i,t2,".");r=t1[1];k=2;while(t1[k]==t2[k]){r=r"."t1[k];k++}}r=r"."$1;printf "%s\t%s\n",$1,r}' > ${data_dir}/pango_designation_alias_key_viralai2.tsv
	(echo 'alias	lineage';cat ${data_dir}/pango_designation_alias_key_viralai1.tsv ${data_dir}/pango_designation_alias_key_viralai2.tsv) > ${data_dir}/pango_designation_alias_key_viralai.tsv
	#rm  ${data_dir}/alias_key.json ${data_dir}/pango_designation_alias_key_viralai1.tsv ${data_dir}/pango_designation_alias_key_viralai2.tsv
	(
	  python  ${scripts_dir}/viralai_fetch_metadata.py --alias ${data_dir}/pango_designation_alias_key_viralai.tsv --csv ${data_dir}/virusseq.metadata.csv.gz
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
	  (cat ${data_dir}/pango_designation_alias_key.json;cat ${data_dir}/viralai.$datestamp.csv | tr ',' ' ') | awk  '$1=="alias"{t[$2]=$3}$1!="alias"{rem=$2;split($2,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $2)}print $1,$2,rem,$3}' |
	  tr ' ' ',' | sed 's/lineage,lineage/raw_lineage,lineage/g'> ${data_dir}/viralai.$datestamp.withalias.csv
	  python3 scripts/pango2vseq.py ${data_dir}/virusseq.$datestamp.metadata.tsv.gz ${data_dir}/viralai.$datestamp.withalias.csv ${data_dir}/virusseq.metadata.csv.gz
	)
fi
echo "getdata" > $checkPointFile
#getdata:

#fetch epidata from multiple sources, These link might change at any time, especially the ON and QC ones. 
wget -O ${data_dir}/AgeCaseCountBC.csv www.bccdc.ca/Health-Info-Site/Documents/BCCDC_COVID19_Dashboard_Case_Details.csv
wget -O ${data_dir}/AgeCaseCountAB.csv https://www.alberta.ca/data/stats/covid-19-alberta-statistics-data.csv
wget -O ${data_dir}/AgeCaseCountQC.csv https://www.inspq.qc.ca/sites/default/files/covid/donnees/covid19-hist.csv?randNum=27899648
wget -O ${data_dir}/AgeCaseCountSK.csv https://dashboard.saskatchewan.ca/export/cases/4565.csv
wget -O ${data_dir}/CanadianEpiData.csv https://health-infobase.canada.ca/src/data/covidLive/covid19-download.csv
wget -O ${data_dir}/AgeCaseCountCAN.csv https://health-infobase.canada.ca/src/data/covidLive/covid19-epiSummary-ageGender.csv
wget --retry-connrefused --waitretry=1 --read-timeout=3600 --timeout=3600 -t 0 -O ${data_dir}/AgeCaseCountON.csv https://data.ontario.ca/datastore/dump/455fd63b-603d-4608-8216-7d8647f43350?bom=True
gzip -f ${data_dir}/AgeCaseCount*.csv

echo "casecount" > $checkPointFile
#casecount:

echo "dataloaded" > $checkPointFile

#dataloaded:

#removes the recombinants
date
echo "separating out the recombinants from the data..."
python3 ${scripts_dir}/extractSequences.py --infile ${data_dir}/virusseq.$datestamp.fasta.xz --metadata ${data_dir}/virusseq.metadata.csv.gz --outfile ${data_dir}/ --extractregex "^X\S*$" --keepregex "^XBB\S*$"

echo "removerecomb" > $checkPointFile


#removerecomb:
date
echo "aligning sequences..."

#All Sequences
python3 ${scripts_dir}/alignment.py ${data_dir}/virusseq.$datestamp.fasta.xz ${data_dir}/virusseq.metadata.csv.gz ${data_dir}/aligned_allSeqs --samplenum 3 --reffile resources/NC_045512.fa; 

#selected recombinants
for variant in `ls $data_dir/*regex*.fasta.xz`; do
	name=${variant##*/}; 
	name=${name%.*};
	name=${name%.*};
	name=`echo $name|cut -d '_' -f3-`;
	echo $variant
	python3 ${scripts_dir}/alignment.py ${data_dir}/Sequences_regex_${name}.fasta.xz ${data_dir}/SequenceMetadata_regex_${name}.tsv.gz ${data_dir}/aligned_recombinant_$name --nosample --reffile resources/NC_045512.fa; 
done

#non-recombinants
python3 ${scripts_dir}/alignment.py ${data_dir}/Sequences_remainder.fasta.xz ${data_dir}/SequenceMetadata_remainder.tsv.gz ${data_dir}/aligned_nonrecombinant --samplenum 3  --reffile resources/NC_045512.fa; 

echo "aligned" > $checkPointFile

#aligned:
for alignedFasta in `ls $data_dir/aligned_*.fasta`; do
	echo $alignedFasta
	date
	iqtree2 -ninit 2 -n 2 -me 0.05 -nt 8 -s $alignedFasta -m GTR -ninit 10 -n 4 --redo; 
done
echo "treebuilt" > $checkPointFile

#treebuilt:
echo "cleaning trees..."
for treefile in `ls $data_dir/aligned_*.treefile`; do
	name=${treefile%.*};
	name=${name%.*};
	recombString="recombinant"
	keeproot="--keep-root"
	echo $keeproot
	if [[ "$name" == *"$recombString"* ]];then
		keeproot=""
	fi
	echo $name
	Rscript ${scripts_dir}/root2tip.R ${name}.fasta.treefile ${name}.rtt.nwk ${name}.dates.tsv; 
	treetime --tree ${name}.rtt.nwk --dates ${name}.dates.tsv --clock-filter 0 --sequence-length 29903 $keeproot --outdir ${name}.treetime_dir;
	python3 ${scripts_dir}/nex2nwk.py ${name}.treetime_dir/timetree.nexus ${name}.timetree.nwk;
done
echo "treecleaned" > $checkPointFile

#treecleaned:
date
echo "knitting the Rmd..."
Rscript -e "rmarkdown::render('duotang.Rmd',params=list(datestamp="\"$datestamp\""))"
echo "duotangbuilt" > $checkPointFile

#duotangbuilt:
Rscript -e "rmarkdown::render('duotang-sandbox.Rmd',params=list(datestamp="\"$datestamp\""))"
echo "duotangsandboxbuilt" > $checkPointFile

#duotangsandboxbuilt:
if [ -f ".secret" ]; then
    secret=`cat .secret`
	python3 scripts/encrypt.py duotang-sandbox.html $secret
	mv duotang-sandbox-protected.html duotang-sandbox.html
else
	echo ".secret file not found, unable to encrypt"
	exit 1
fi
echo "htmlencrypted" > $checkPointFile

#htmlencrypted:
if [ "$BUILDMAIN" = "YES" ]; then 
	scripts/getPastDuotangVersions.sh
fi
echo "archive" > $checkPointFile

#archive
if [ "$BUILDMAIN" = "YES" ]; then 
	git status
	git add *.html
	git add archive/*.html
	git commit -m "Update: $datestamp"
	git push origin main
fi

echo "Update completed successfully"
echo "finish" > $checkPointFile


#cleanup:
if [ "$CLEAN" = "YES" ]; then 
	echo "Removing temporary files..."
	mkdir -p ${data_dir}/$datestamp
fi

if [ "$NOCONDA" = "NO" ]; then 
	conda deactivate
fi
