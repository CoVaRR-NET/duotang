zcat ../data_needed/virusseq.metadata.csv.gz | cut -f19,38 | grep EPI | sort -k1,1 > temp_vssampledate &

tar -xvf $(ls metadata_tsv_*.tar.xz | tail -n 1) metadata.tsv -O| tr ' ' '_' |  awk 'substr($6,1,22)=="North_America_/_Canada"||NR==1' > temp_metadata_gisaid_canada.tsv

cat header_corresp_VirusSeq_GISAID temp_metadata_gisaid_canada.tsv | sed 's/Toronto/Ontario/' | sed 's/North_America_\/_Canada_\/_//' | sed 's/North_America_\/_Canada/NA/' | sed 's/_\/_[^\t]*//' | sed 's/\t\t/\tNA\t/g' | sed 's/\t\t/\tNA\t/g' | awk 'NF==2{d[$2]=$1;h=0}NF!=2 && h==1{for(i=1;i<=NF;i++){if(i in dd){printf "%s\t",$i}}printf "\n"}NF!=2 && h==0{h=1;for(i=1;i<=NF;i++){if($i in d){dd[i]=1;printf "%s\t",d[$i]}}printf "\n"}' | sed 's/_-_/-/' > temp_metadata_gisaid_canada_changeformat.tsv

cat ../data_needed/pango_designation_alias_key_viralai.tsv temp_metadata_gisaid_canada_changeformat.tsv | sed 's/Newfoundland\t/Newfoundland_and_Labrador\t/' | awk 'NF==2{t[$1]=$2}NF!=2{rem=$7;split($7,p,".");if(p[1] in t){gsub(p[1] , t[p[1]], $7)}$7=rem" "$7;print}' | sed 's/lineage lineage/lineage raw_lineage/' | tr ' ' '\t' | sort -k2,2 > temp_metadatagisaid_beforecorrection.tsv

join -1 1 -2 2 -a 2 -o auto -e"NA" temp_vssampledate temp_metadatagisaid_beforecorrection.tsv | awk '$2!=$4 && $2!="NA"{$4=$2}{print}' | awk 'length($4)==7{$4=$4"-15"}{print}' | awk 'length($4)==4{$4=$4"-01-01"}{print}' | tr ' ' '\t' |  sort -rk2,2 | cut -f3- | awk 'BEGIN { OFS = "\t" }NR!=1{gsub("_"," ", $3)}{print}' |  gzip > metadatagisaid.tsv.gz

rm temp_*
