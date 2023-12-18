#!/bin/bash

#simple checks to make sure the script is ran at root of main branch
if test -f "duotang.html"; then
    echo "check:current dir is repo root. - YES"
else
    echo "check:current dir is repo root. - NO"
	echo "Make sure this script is ran at the root of the main branch."
	exit
fi

if git rev-parse --abbrev-ref HEAD | grep -q 'main'; then
    echo "check:on main branch. - YES"
else
    echo "check:on main branch. - NO"
	echo "Make sure this script is ran at the root of the main branch."
	exit
fi

gh pr list --state closed --limit 1000 | grep "Update:" | grep "MERGED" | cut -f5 | cut -d' ' -f1 > prHistoryDates.txt
#pull all commits with changes to duotang.html
git log --pretty=%ad,%H --date=short --name-only -- duotang.html | tr ':' '_'> commitHistory.txt
#remove empty lines
sed -i '/^$/d' commitHistory.txt
#joins every 2 lines together
paste - - -d, < commitHistory.txt > commitHistory2.txt
#remove anything thats linked to the data/needed folder
sed -i '/data_needed/d' commitHistory2.txt

tac commitHistory2.txt > commitHistory.txt

mapfile -t dates < prHistoryDates.txt

while IFS=, read -r date hash name || [ -n "$date" ]; do
    # Check if the date is in the array from the second file
    if [[ " ${dates[*]} " == *" $date "* ]]; then
        # Print or process the matching line from the first file
        echo "$date,$hash,$name"
    fi
done < commitHistory.txt > commitHistory2.txt

tac commitHistory2.txt | sort -t',' -k1,1 -u | tac > commitHistory.txt

#awk -F',' '!seen[$1]++' "commitHistory.txt" > commitHistory.txt

lastestArchiveDate=$(ls archive/ | grep -v "readme.md" | tac | head -1)
echo $lastestArchiveDate
lastestArchiveDate=$(date -d $lastestArchiveDate +%s) || lastestArchiveDate=0
lastDate=1

mkdir -p archive
#echo "Here we store old versions of the duotang notebook:" > archive/readme.md
#recreate the duotang.html file from each commit and save it
for i in `cat commitHistory.txt | sed '1!G;h;$!d'`; do
	echo $i;
	name=`echo $i | cut -d',' -f3`
	commit=`echo $i | cut -d',' -f1`
	id=`echo $i | cut -d',' -f2`
	date=`echo $commit | cut -d'.' -f1`
	
	parsedDate=$(date -d $commit +%s)
	
	#check that the commit was made on a date after the latest available archive file date so we dont pull past files every time.
	if [ $lastestArchiveDate -lt $parsedDate ]; then
		if [ $parsedDate -eq $lastDate ]; then
			echo "Not the latest commit"
		else
			mkdir -p archive/$commit
			#echo "$id:$name"
			git show $id:$name > archive/$commit/$commit.html
			if [ -s archive/$commit/$commit.html ]; then
				# echo the hyperlink to the readme
				#echo "- [$date](./$commit/$commit.html)" >> archive/readme.md
				sed -i "2i- [$date](./$commit/$commit.html)" archive/readme.md
				for j in `git ls-tree --name-only -r $id | grep duotang_files`; do #pull all the files in the duotang_files folder
					path=`dirname $j`
					#echo $j
					mkdir -p archive/$commit/$path
					git show $id:$j > archive/$commit/$j
				done;
				
				mkdir -p archive/$commit/downloads
				SAVEIFS=$IFS #our filenames have spaces in them, we so must ignore them for this for loop
				IFS=$(echo -en "\n\b")
				for j in `git ls-tree --name-only -r $id | grep downloads`; do #pull the files in download filder
					#echo ${j}	
					git show $id:"${j}" > archive/$commit/${j}
				done;
				IFS=$SAVEIFS #reset ifs
			else
				# The file is empty, sometimes the symlink for follow pulls up random files not related to duotang,html, just delete it.
				rm -rf archive/$commit/$commit.html
			fi
		fi
		
	else
		#echo "- [$date](./$commit/$commit.html)" >> archive/readme.md #echo the link into the read me because we cleared it.
		echo "commit was before that latest archive date, delete the archive folder to rebuild."
		
	fi   
	lastDate=$parsedDate
done;
#cleanup
uniq archive/readme.md > archive/readme2.md
mv archive/readme2.md archive/readme.md
rm commitHistory.txt
rm commitHistory2.txt
rm prHistoryDates.txt
