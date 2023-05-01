#!/bin/bash
####################BIG BOLDED WARNING MESSAGE######################
#  This script contains onErrorResume functionality.               # 
#  Labels for these goto function start with '#' and end with ':'  #
#  For example: "#LabelName:", "#datalabel:"					   #
#  They must be the same as content of the checkpoint file         #
#  THEY ARE NOT COMMENTS, DO NOT DELETE THEM.					   #
####################################################################

set -e #set the script to exit on error.

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
  	--venvpath)
      VENVPATH="$2"
      shift # past argument
      shift # past value
      ;;
	--downloadonly)
      DOWNLOADONLY="YES"
      shift # past argument
      ;;
	--includegsd)
      INCLUDEGSD="YES"
      shift # past argument
      ;;
	--gitpull)
      GITPULL="YES"
      shift # past argument
      ;;
  	--gitpush)
      GITPUSH="YES"
      shift # past argument
      ;;
	--liststeps)
      LISTSTEPS="YES"
      shift # past argument
      ;;
	--gotostep)
      GOTOSTEP="$2"
      shift # past argument
      shift # past value
      ;;
	--dryrunpass)
      DRYRUN="PASS"
      shift # past argument
      ;;
	--dryrunfail)
      DRYRUN="FAIL"
      shift # past argument
      ;;
	--help)
      HELPFLAG="YES"
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
if [[ "$DRYRUN" = "PASS" ]]; then 
	cp tests/pass.log ./update.log
	cp tests/pass.log ./rebuild.log
	echo "dry run passed"
	exit
fi

if [[ "$DRYRUN" = "FAIL" ]]; then 
	cp tests/fail.log ./update.log
	cp tests/fail.log ./rebuild.log

	echo "dry run failed"
	exit
fi

if [ -z "$DATE" ]; then DATE=`date --utc +%F`; fi
if [ -z "$SOURCE" ]; then SOURCE="viralai"; fi
if [ -z "$data_dir" ]; then data_dir="data_needed"; fi
if [ -z "$scripts_dir" ]; then scripts_dir="scripts"; fi
if [ "$OVERWRITE" = "YES" ]; then rm $checkPointFile; else OVERWRITE="NO"; fi
if [ "$BUILDMAIN" = "YES" ]; then BUILDMAIN="YES"; else BUILDMAIN="NO"; fi
if [ "$CLEAN" = "YES" ]; then CLEAN="YES"; else CLEAN="NO"; fi
if [ "$DOWNLOADONLY" = "YES" ]; then DOWNLOADONLY="YES"; else DOWNLOADONLY="NO"; fi
if [ "$INCLUDEGSD" = "YES" ]; then INCLUDEGSD="YES"; else INCLUDEGSD="NO"; fi
if [ "$GITPUSH" = "YES" ]; then GITPUSH="YES"; else GITPUSH="NO"; fi
if [ "$LISTSTEPS" = "YES" ]; then 
	echo "Available checkpoint steps are: "
	echo $(cat update.sh | grep '^#.*:$' | sed 's/#//' | sed 's/://')
	exit 0
fi
if [ "$HELPFLAG" = "YES" ]; then 
	echo -e "This script attempts to automate the data download, data processing, and knitting process of building CoVaRR-Net Duotang.\n\n"
	echo "Available arguments:"
	echo "[-d|--date] String in format 'YYYY-MM-DD'. This will be the datestamped used throughout the build process (default: CurrentUTCDate)"
	echo "[-s|--source] String. The value can be 'viralai' or 'virusseq', this will be the genomic datasource used (default: viralai)."
	echo "[-o|--outdir] String. The output directory of all but the HTML files (default: ./data_needed). "
	echo "[-f|--scriptdir] String. The ABSOLUTE path to the scripts directory (default: \${PWD}/scripts)."
	echo "[--overwrite] Flag for discarding current checkpoints and restart update from beginning"
	echo "[--buildmain] Flag used to knit the RMD and push the changes to the main branch for publishing."
	echo "[--downloadonly] Flag used to download data only. Script will exit once all external resources had been downloaded. "
	echo "[--noconda] Flag used to run the update script without conda. Note: The dependencies should exist in \$PATH and this script makes no attempt to ensure that they exist. "
	echo "[--venvpath] String. The ABSOLUTE path to the venv containing dependencies. Should be used with '--noconda'."
	echo "[--includegsd] Flag used to include the GSD metadata download. "
	echo "[--gitpush] Flag used to automatically commit changes and push to dev."
	echo "[--clean] [BROKEN] Flag used to clean the data_needed directory after update. Currently it just dumps the new data_needed files into a tarball at root."
	echo "[--liststeps] Prints the available checkpoint steps in this script. You can use this for the '--gotostep' argument."	
	echo "[--gotostep] Jumps to a checkpoint step in the script, specify it as '#StepName:'. You must include the # at beginning and : at end. Use '--liststeps' to see all the available checkpoints. "
	exit 0
fi

if [ "$GITPULL" = "YES" ]; then 
	echo "Pulling in the latest changes. This flag should only be used if there are no changes in git status."
	echo "Actually I don't know why this is even a flag in the first place. I can see so many issues with including this as part of the update script"
	echo "You just shouldn't use this flag, or expect the script to act funky."
	#git pull
	exit 1
fi

if [ "$NOCONDA" = "YES" ]; then 
	NOCONDA="YES"; 
	echo -e "\n\nThis script is running without Conda, make sure dependencies are set up according to CONTRIBUTING.md"
	#if command -v python3; then 
#		echo "Using python3 at $(command -v python3)"
	#else
		if [ ! -z "$VENVPATH" ]; then
			echo "Using the venv: ${VENVPATH}";
			source ${VENVPATH}/bin/activate
		else
			echo "Not using Conda and venv path is not specified with --venvpath, attempt to use dependencies with system level installs"
			if command -v python3; then 
				echo "Using python3 at $(which python3)"
			else
				echo "Python3 not found, please check your dependencies"
				exit 1
			fi
		fi
	#fi
else 
	if command -v conda; then 
		NOCONDA="NO"; 
		eval "$(conda shell.bash hook)"
		conda activate duotang
	else 
		echo "Conda not found, make sure conda is in $PATH or use the --noconda flag"
		exit 1
	fi
fi

echo -e "\n\nHere are the config being used: \n"

echo "Datestamp used: ${DATE}"
echo "Data source: ${SOURCE}"
echo "Data will be written to: ${data_dir}"
echo "Script folder located at: ${scripts_dir}"
echo "Overwrite checkpoints: ${OVERWRITE}"
echo "Download data only?: ${DOWNLOADONLY}"
echo "Include GSD download?: ${INCLUDEGSD}"
echo "Push changes to git?: ${GITPUSH}"
echo "Clean up mode: ${CLEAN}"
echo "Not using Conda?: ${NOCONDA}"
if [ ! -z "$VENVPATH" ]; then echo "VENV path is: ${VENVPATH}"; fi
if [ ! -z "$GOTOSTEP" ]; then echo "Skipping to step $GOTOSTEP"; fi

echo ""
echo ""
datestamp=$DATE

#this doesnt work when backgrounded.
#read -p "Press any key to start the update, or ctrl+C to adjust config"

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

if [ ! -z "$GOTOSTEP" ]; then 
	echo "Skipping to step $GOTOSTEP"
	jumpTo $GOTOSTEP 
fi

if [ "$BUILDMAIN" = "YES" ]; then 
	jumpTo knitduotang 
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
        echo "A previous update finished without error, delete the checkpoint file to overwrite the data, or use the --overwrite flag. exiting"
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
#get the timestamp for file name
echo version will be stamped as : $datestamp
echo "lineagedata" > $checkPointFile

#lineagedata:
#get the json containing aliases
wget -O ${data_dir}/lineageNotes.tsv https://raw.githubusercontent.com/cov-lineages/pango-designation/master/lineage_notes.txt

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
' | tr ' ' '\t' | sed '/^\t$/d' >  ${data_dir}/pango_designation_alias_key.tsv


echo "ncovfasta" > $checkPointFile
#ncovfasta:

#get the fasta from ncov
wget -O ${data_dir}/ncov-open.$datestamp.fasta.xz https://data.nextstrain.org/files/ncov/open/sequences.fasta.xz  #> /dev/null 2>&1
echo "ncovmetadata" > $checkPointFile

#ncovmetadata:
#get the metadata from ncov and add a column with raw names (eg: BA.5 is B.1.1.529.5)
wget -O ${data_dir}/ncov-open.$datestamp.tsv.gz https://data.nextstrain.org/files/ncov/open/metadata.tsv.gz # > /dev/null 2>&1
	(
	  cat ${data_dir}/pango_designation_alias_key.tsv;
	  zcat ${data_dir}/ncov-open.$datestamp.tsv.gz | tr ' ' '_' | sed 's/\t\t/\tNA\t/g' | sed 's/\t\t/\tNA\t/g'| sed 's/\t$/\tNA/g'
	  ) |
	awk  '$1=="alias"{t[$2]=$3;next;}$1=="strain"{for(i=1;i<=NF;i++){if($i=="pango_lineage"){col=i;print $0,"raw_lineage";next;}}}{rem=$i;split($i,p,".");if(p[1] in t){gsub(p[1]"." , t[p[1]]".", $i)};raw=$i;$i=rem;print $0,raw}' |
	tr ' ' '\t'  | gzip > ${data_dir}/ncov-open.$datestamp.withalias.tsv.gz
echo "virusseq" > $checkPointFile
#virusseq:

if [[ $SOURCE == "viralai" ]]; then
	#set the endpoints for dnastack databases. Only required on first run. 
	dnastack config set collections.url https://viral.ai/api/
	dnastack config set drs.url https://viral.ai/

    echo "Data source is ViralAi"
    (
      python3  ${scripts_dir}/viralai_fetch_metadata.py --alias ${data_dir}/pango_designation_alias_key.tsv --csv ${data_dir}/virusseq.metadata.csv.gz
    )
    (
      mkdir -p  ${data_dir}/temp
      python3  ${scripts_dir}/viralai_fetch_fasta_url.py --seq ${data_dir}/temp/fasta_drl.$datestamp.txt
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
echo "epidata" > $checkPointFile
#epidata:

#fetch epidata from multiple sources, These link might change at any time, especially the ON and QC ones. 

#set +e #ontario's API sucks. dont crash the script if it times out and just continue. Better luck next week.
#wget --retry-connrefused --waitretry=1 --read-timeout=3600 --timeout=3600 -t 0 -O ${data_dir}/AgeCaseCountON.csv https://data.ontario.ca/datastore/dump/455fd63b-603d-4608-8216-7d8647f43350?bom=True || rm AgeCaseCountON.csv
#set -e #set the stop on error flag back.

wget -O ${data_dir}/AgeCaseCountON.csv https://data.ontario.ca/dataset/f4112442-bdc8-45d2-be3c-12efae72fb27/resource/455fd63b-603d-4608-8216-7d8647f43350/download/conposcovidloc.csv || rm AgeCaseCountON
wget -O ${data_dir}/AgeCaseCountBC.csv www.bccdc.ca/Health-Info-Site/Documents/BCCDC_COVID19_Dashboard_Case_Details.csv || rm AgeCaseCountON.csv
wget -O ${data_dir}/AgeCaseCountAB.csv https://www.alberta.ca/data/stats/covid-19-alberta-statistics-data.csv || rm AgeCaseCountAB.csv
wget -O ${data_dir}/AgeCaseCountQC.csv https://www.inspq.qc.ca/sites/default/files/covid/donnees/covid19-hist.csv?randNum=27899648 || rm AgeCaseCountQC.csv
#wget -O ${data_dir}/AgeCaseCountSK.csv https://dashboard.saskatchewan.ca/export/cases/4565.csv || rm AgeCaseCountON.csv
wget -O ${data_dir}/CanadianEpiData.csv https://health-infobase.canada.ca/src/data/covidLive/covid19-download.csv || rm CanadianEpiData.csv
wget -O ${data_dir}/AgeCaseCountCAN.csv https://health-infobase.canada.ca/src/data/covidLive/covid19-epiSummary-ageGender.csv || rm AgeCaseCountCAN.csv
gzip -f ${data_dir}/AgeCaseCount*.csv

echo "gsdmetadata" > $checkPointFile

#gsdmetadata:
if [ "$INCLUDEGSD" = "YES" ]; then 
	echo "downloading GSD metadata"
	python3 ${scripts_dir}/downloadGSD.py ${data_dir}/GSDmetadata.tar.xz
	# Extract GISAID id and collection date 
	zcat ${data_dir}/virusseq.metadata.csv.gz | cut -f19,38 | grep EPI | sort -k1,1 > ${data_dir}/temp_vssampledate
	#Extracting Canadian sequences in last GISAID metadata 
	tar -xvf $(ls ${data_dir}/GSDmetadata.tar.xz | tail -n 1) metadata.tsv -O| tr ' ' '_' |  awk 'substr($6,1,22)=="North_America_/_Canada"||NR==1' > ${data_dir}/temp_metadata_gisaid_canada.tsv

	#Rename and keep the columns according to header_corresp_VirusSeq_GISAID
	#Correct a few spotted errors from metadata file
	echo -e "fasta_header_name Virus_name\nGISAID_ID Accession_ID\ngeo_loc_name_state_province_territory Location\nhost_gender Gender\nhost_age_bin Patient_age\nsample_collection_date Collection_date\npurpose_of_sampling Is_high_coverage?\npurpose_of_sequencing Is_low_coverage?\nsample_collected_by Is_reference?\nlineage Pango_lineage" > ${data_dir}/header_corresp_VirusSeq_GISAID

	cat ${data_dir}/header_corresp_VirusSeq_GISAID ${data_dir}/temp_metadata_gisaid_canada.tsv | sed 's/Toronto/Ontario/' | sed 's/North_America_\/_Canada_\/_//' | sed 's/North_America_\/_Canada/NA/' | sed 's/_\/_[^\t]*//' | sed 's/Newfoundland\t/Newfoundland_and_Labrador\t/' |  sed 's/\t\t/\tNA\t/g' | sed 's/\t\t/\tNA\t/g' | awk 'NF==2{d[$2]=$1;h=0}NF!=2 && h==1{for(i=1;i<=NF;i++){if(i in dd){printf "%s\t",$i}}printf "\n"}NF!=2 && h==0{h=1;for(i=1;i<=NF;i++){if($i in d){dd[i]=1;printf "%s\t",d[$i]}}printf "\n"}' | sed 's/_-_/-/' > ${data_dir}/temp_metadata_gisaid_canada_changeformat.tsv

	cat ${data_dir}/pango_designation_alias_key.tsv ${data_dir}/temp_metadata_gisaid_canada_changeformat.tsv | awk 'NF==2{t[$1]=$2}NF!=2{rem=$7;split($7,p,".");if(p[1] in t){gsub(p[1] , t[p[1]], $7)}$7=rem" "$7;print}' | sed 's/lineage lineage/lineage raw_lineage/' | tr ' ' '\t' | sort -k2,2 > ${data_dir}/temp_metadatagisaid_beforecorrection.tsv

	join -1 1 -2 2 -a 2 -o auto -e"NA" ${data_dir}/temp_vssampledate ${data_dir}/temp_metadatagisaid_beforecorrection.tsv | awk '$2!=$4 && $2!="NA"{$4=$2}{print}' | awk 'length($4)==7{$4=$4"-15"}{print}' | awk 'length($4)==4{$4=$4"-01-01"}{print}' | tr ' ' '\t' |  sort -rk2,2 | cut -f3- | awk 'BEGIN { OFS = "\t" }NR!=1{gsub("_"," ", $3)}{print}' |  gzip > ${data_dir}/GSDMetadataCleaned.tsv.gz
fi

if [ "$DOWNLOADONLY" = "YES" ]; then
	echo "Data download complete, exiting..."
	echo "finish" > $checkPointFile
	exit 0
fi

echo "filterseq" > $checkPointFile

#filterseq:
#removes the recombinants

echo "separating out the recombinants from the data..."
python3 ${scripts_dir}/extractSequences.py --infile ${data_dir}/virusseq.$datestamp.fasta.xz --metadata ${data_dir}/virusseq.metadata.csv.gz --outfile ${data_dir}/ --extractregex "^X\S*$" --keepregex "^XBB\S*$"

echo "alignseq" > $checkPointFile

#alignseq:
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
python3 ${scripts_dir}/alignment.py ${data_dir}/Sequences_remainder.fasta.xz ${data_dir}/SequenceMetadata_remainder.tsv.gz ${data_dir}/aligned_nonrecombinant --samplenum 1  --reffile resources/NC_045512.fa; 

echo "buildtree" > $checkPointFile

#buildtree:
for alignedFasta in `ls $data_dir/aligned_*.fasta`; do
	echo $alignedFasta
	iqtree2 -ninit 2 -n 2 -me 0.05 -nt 8 -s $alignedFasta -m GTR -ninit 10 -n 8 --redo; 
done
echo "cleantree" > $checkPointFile

#cleantree:
echo "cleaning trees..."

for treefile in `ls $data_dir/aligned_*.treefile`; do
	name=${treefile%.*};
	name=${name%.*};
	recombString="recombinant"
	keeproot="--keep-root"
	if [[ "$name" == *"$recombString"* ]];then
		keeproot=""
	fi
	echo $name
	Rscript ${scripts_dir}/root2tip.R ${name}.fasta.treefile ${name}.rtt.nwk ${name}.dates.tsv; 
	treetime --tree ${name}.rtt.nwk --dates ${name}.dates.tsv --clock-filter 0 --sequence-length 29903 $keeproot --outdir ${name}.treetime_dir;
	python3 ${scripts_dir}/nex2nwk.py ${name}.treetime_dir/timetree.nexus ${name}.timetree.nwk;
done
python scripts/UpdateStatusManager.py --action set --key LastTreeUpdate --value $datestamp


echo "knitduotang" > $checkPointFile

#knitduotang:
echo "knitting the Rmd..."
Rscript -e "rmarkdown::render('duotang.Rmd',params=list(datestamp="\"$datestamp\""))"
echo "knitsandbox" > $checkPointFile

#knitsandbox:
#Rscript -e "rmarkdown::render('duotang-sandbox.Rmd',params=list(datestamp="\"$datestamp\""))"
echo "knitgsd" > $checkPointFile

#knitgsd:
#Rscript -e "rmarkdown::render('duotang-GSD.Rmd',params=list(datestamp="\"$datestamp\""))"
echo "encrypt" > $checkPointFile

#encrypt:
#if [ -f ".secret/sandbox" ]; then
#    secret=`cat .secret/sandbox`
#	python3 scripts/encrypt.py duotang-sandbox.html $secret
#	python3 scripts/encrypt.py duotang-GSD.html $secret

#	mv duotang-sandbox-protected.html duotang-sandbox.html
#	mv duotang-GSD-protected.html duotang-GSD.html

#else
#	echo ".secret file not found, unable to encrypt."
#	echo "Make a 'sandbox' text file in the .secret directory, put a password in it. "
#	echo "For example e.g. echo 'Hunter2' > .secret/sandbox"
#	echo "DO NOT ADD THIS FILE TO GIT."
#	rm -f duotang-sandbox.html
#	rm -f duotang-GSD.html
#	echo "duotangbuilt" > $checkPointFile
#	exit 1
#fi

echo "cleanup" > $checkPointFile

#cleanup:
if [ "$CLEAN" = "YES" ]; then 
	echo "Removing temporary files..."
	mkdir -p ${data_dir}/$datestamp
	cp ${data_dir}/AgeCase* ${data_dir}/$datestamp
	cp ${data_dir}/*.nwk ${data_dir}/$datestamp
	cp ${data_dir}/CanadianEpiData.csv ${data_dir}/$datestamp
	cp ${data_dir}/lineageNotes.tsv ${data_dir}/$datestamp
	cp ${data_dir}/virusseq.$datestamp.fasta.xz ${data_dir}/$datestamp
	cp ${data_dir}/virusseq.metadata.csv.gz ${data_dir}/$datestamp
	cp ${data_dir}/GSDMetadataCleaned.tsv.gz ${data_dir}/$datestamp
	tar -cvf - ${data_dir}/$datestamp | xz -9 - > update.$datestamp.tar.xz
	rm -rf ${data_dir}/$datestamp
fi

echo "recordversion" > $checkPointFile
#echo "$datestamp" > duotangCurVer
python scripts/UpdateStatusManager.py --action set --key LastUpdated --value $datestamp

echo "gitpush" > $checkPointFile

#gitpush:
if [ "$GITPUSH" = "YES" ]; then 
	#if [ "$BUILDMAIN" = "YES" ]; then 
	#git remote prune origin
	#git checkout -B UpdatePreview
	bash scripts/getPastDuotangVersions.sh
	cp data_needed/virusseq.$datestamp.fasta.xz data_needed/virusseq.fasta.xz
	git status
	git add -f data_needed/*.nwk
	git add -f data_needed/virusseq.metadata.csv.gz
	git add -f data_needed/AgeCaseCount*
	git add -f data_needed/CanadianEpiData.csv
	git add -f data_needed/lineageNotes.tsv
	git add -f data_needed/virusseq.fasta.xz
	git add -f archive/*.html
	git add -f archive/readme.md
	git add -f downloads/*
	git add -f duotang*html
	#git add -f duotangCurVer
	git add -f DuotangUpdateStatus.json
	git commit -m "Update: $datestamp"
	git push origin dev
	sed  "s/{updatedate}/$datestamp/g" ./whatsnew.md > ./whatsnew.send.md
	#set +e #workaround so the rebuild doesnt crash here. probably better to use || but this works.
	gh pr create -B main -F ./whatsnew.send.md --title "Update: $datestamp"
	#set -e
	#python scripts/duoli.py --message "Here are the preview HTMLs for update $datestamp." --file duotang.html --file duotang-sandbox.html --file duotang-GSD.html

	#git checkout dev
fi


if [ "$NOCONDA" = "NO" ]; then 
	conda deactivate
fi


echo "Update completed successfully"
echo "finish" > $checkPointFile
