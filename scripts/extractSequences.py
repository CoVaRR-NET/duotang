###############extractSequences.py###############
# * Justin Jia https://github.com/bfjia
# * Initial release 2023/01/23
# * This script attempts to extract specific sequences from the --infile (XZ compressed) following some regex pattern
# * then outputs both the extract sequences and leftover sequences, and their metadata to separate compressed fasta files
# * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# * Required args: infile, metadata, outfile.
# * option args: regex (defaults to pulling out all recombinants), 
#                extractbyid (use if the regex should be applied to the isolate column to pull out specific sequences)

from Bio.Seq import Seq
from Bio import SeqIO
import gzip
import lzma
import argparse
import urllib.request
import json
import re


if __name__ == "__main__":
    # command line interface
    parser = argparse.ArgumentParser("Down-sample genome data in xz-compressed file and output reference-aligned sequences.")

    parser.add_argument("--infile", type=str, default="../data_needed/virusseq.fasta.xz",
                        help="input, xz-compressed FASTA file from virusseq.py")
    parser.add_argument("--metadata", type=str,default="../data_needed/virusseq.metadata.csv.gz",
                        help="input, gz-compressed metadata file from pango2seq.py")
    parser.add_argument("--outfile", type=str, default="../data_needed",
                        help="output, path to write FASTA.XZ and metadata files")
    parser.add_argument("--extractregex", type=str, default="(^|.)X..",
                        help="regex used to extract lineages from all data. i.e. blacklist")
    parser.add_argument("--keepregex",action='extend', nargs="+",  default=["(^|.)X.."],
                        help="regex used to keep lineages from extracted data. i.e. whitelist")
    parser.add_argument("--extractbyid", action=argparse.BooleanOptionalAction,
                        help="bool, specifies that the regex should be applied to ID rather than lineage")
    args = parser.parse_args()
    if (len(args.keepregex) == 0):
        args.keepregex = [args.extractregex]
    print("extractregex is: " + args.extractregex)
    print("keepregex is: " + ",".join(args.keepregex))

    idToKeep = []
    idToRemove = []
    idToWhitelist = {}

    metadataBlacklist = []
    metadataWhitelist = {}
    metadataRemainder = []
    
    print("outputting metadata...")
    #first we use the extractregex variable to remove sequences (blacklist)
    with gzip.open(args.metadata, 'rt', encoding='utf-8') as fh:
        for line in fh:
            #if metadata belongs to the regex being searched
            if (args.extractbyid == True):
                strToMatch = line.split('\t')[0] #isolate column
            else:
                strToMatch = line.split('\t')[-1] #raw lineage column

            if (re.search(args.extractregex, strToMatch)):
                idToRemove.append(line.split('\t')[23])
                metadataBlacklist.append(line)
            else:
                idToKeep.append(line.split('\t')[23])
                metadataRemainder.append(line)
    metadataBlacklist.insert(0, metadataRemainder[0])
    
    #now we use keepregex to keep sequences from the removed pile
    for regex in args.keepregex:
        ids = []
        md = []
        for line in metadataBlacklist:
            #if metadata belongs to the regex being searched
            if (args.extractbyid == True):
                strToMatch = line.split('\t')[0]
            else:
                strToMatch = line.split('\t')[-1]

            if (re.search(regex, strToMatch)):
                ids.append(line.split('\t')[23])
                md.append(line)
        idToWhitelist[''.join([i for i in regex if i.isalpha()])] = ids
        md.insert(0, metadataRemainder[0])
        metadataWhitelist[''.join([i for i in regex if i.isalpha()])]= md
    
    for key in idToWhitelist.keys():
        with gzip.open(args.outfile + "/SequenceMetadata_regex_" + key.replace("\\","") + ".tsv.gz", 'wt') as fh:
            for line in metadataWhitelist[key]:
                fh.write(line)

    with gzip.open(args.outfile + "/SequenceMetadata_matched.tsv.gz", 'wt') as fh:
        for line in metadataBlacklist:
            fh.write(line)
    
    with gzip.open(args.outfile + "/SequenceMetadata_remainder.tsv.gz", 'wt') as fh:
        for line in metadataRemainder:
            fh.write(line)

    print("parsing through sequences...")
    recordsMatched = {}
    recordsRemainder = []
    with lzma.open(args.infile, "rt", encoding='utf-8') as rfh:
        for record in SeqIO.parse(rfh, "fasta"):
            if (any(record.id in id for id in idToRemove)):
                for key in idToWhitelist:
                    if (any(record.id in id for id in idToWhitelist[key])):
                        if (key not in recordsMatched):
                            recordsMatched[key] = [record]
                        else:
                            recordsMatched[key].append(record)
            else:
                recordsRemainder.append(record)


    print("outputting matched sequences...")
    for key in recordsMatched:
        with lzma.open(args.outfile + "/Sequences_regex_" + key.replace("\\","") + ".fasta.xz", 'wt', encoding='utf-8') as wfh:
            for record in recordsMatched[key]:
                wfh.write(">" + record.id + "\n" + str(record.seq) + "\n")
    
    print("outputting remainder sequences, this step takes a while... go for a break :)")
    with lzma.open(args.outfile + "/Sequences_remainder.fasta.xz", 'wt', encoding='utf-8') as wfh:
        for record in recordsRemainder:
            wfh.write(">" + record.id + "\n" + str(record.seq)+ "\n")


