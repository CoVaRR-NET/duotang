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

#pull all commits with changes to duotang.html
git log --pretty=%as.%H --follow --name-only -- duotang.html > commitHistory.txt
#remove empty lines
sed -i '/^$/d' commitHistory.txt
#joins every 2 lines together
paste - - -d, < commitHistory.txt > commitHistory2.txt
#remove anything thats linked to the data/needed folder
sed -i '/data_needed/d' commitHistory2.txt

mkdir -p archive
echo "Here we store old versions of the duotang notebook:" > archive/readme.md
#recreate the duotang.html file from each commit and save it
for i in `cat commitHistory2.txt`; do
	echo $i;
	name=`echo $i | cut -d',' -f2`
	commit=`echo $i | cut -d',' -f1`
	id=`echo $commit | cut -d'.' -f2`
	date=`echo $commit | cut -d'.' -f1`
	git show $id:$name > archive/$commit.html
	if [ -s archive/$commit.html ]; then
        # echo the hyperlink to the readme
        echo "- [$date]($commit.html)" >> archive/readme.md
	else
		# The file is empty, sometimes the symlink for follow pulls up random files not related to duotang,html, just delete it.
		rm -f archive/$commit.html
	fi
done;
#cleanup
rm commitHistory.txt
rm commitHistory2.txt
