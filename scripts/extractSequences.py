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

    parser.add_argument("--infile", type=str, 
                        help="input, xz-compressed FASTA file from virusseq.py")
    parser.add_argument("--metadata", type=str,
                        help="input, gz-compressed metadata file from pango2seq.py")
    parser.add_argument("--outfile", type=str, 
                        help="output, path to write FASTA.XZ and metadata files")
    parser.add_argument("--regex", type=str, default="^X\S*$",
                        help="regex used to extract lineages")
    parser.add_argument("--extractbyid", action=argparse.BooleanOptionalAction,
                        help="bool, specifies that the regex should be applied to ID rather than lineage")
    args = parser.parse_args()
    print("regex is: " + args.regex)
    idToExtract = []
    metadataMatched = []
    metadataRemainder = []
    #read in the metadata file
    with gzip.open(args.metadata, 'rt', encoding='utf-8') as fh:
        for line in fh:
            #if metadata belongs to the regex being searched
            if (args.extractbyid == True):
                strToMatch = line.split('\t')[0]
            else:
                strToMatch = line.split('\t')[1]

            if (re.search(args.regex, strToMatch)):
                idToExtract.append(line.split('\t')[23])
                metadataMatched.append(line)
            else:
                metadataRemainder.append(line)
    metadataMatched.insert(0, metadataRemainder[0])
    
    print("outputting metadata...")
    with gzip.open(args.outfile + "/SequenceMetadata_matched.tsv.gz", 'wt') as fh:
        for line in metadataMatched:
            fh.write(line)
    with gzip.open(args.outfile + "/SequenceMetadata_remainder.tsv.gz", 'wt') as fh:
        for line in metadataRemainder:
            fh.write(line)

    print("parsing through sequences...")
    recordsMatched = []
    recordsRemainder = []
    with lzma.open(args.infile, "rt", encoding='utf-8') as rfh:
        for record in SeqIO.parse(rfh, "fasta"):
            if (any(record.id in id for id in idToExtract)):
                recordsMatched.append(record)
            else:
                recordsRemainder.append(record)

    print("outputting matched sequences...")
    with lzma.open(args.outfile + "/Sequences_matched.fasta.xz", 'wt', encoding='utf-8') as wfh:
        for record in recordsMatched:
            wfh.write(">" + record.id + "\n" + str(record.seq) + "\n")
    
    print("outputting remainder sequences, this step takes a while... go for a break :)")
    with lzma.open(args.outfile + "/Sequences_remainder.fasta.xz", 'wt', encoding='utf-8') as wfh:
        for record in recordsRemainder:
            wfh.write(">" + record.id + "\n" + str(record.seq)+ "\n")


