import argparse
import csv
import gzip
import sys

parser = argparse.ArgumentParser("Append Pangolin outputs to VirusSeq metadata")
parser.add_argument("metadata", type=str, help="<input> VirusSeq metadata TSV file (can be .gz)")
parser.add_argument("lineages", type=str, help="<input> CSV containing Pangolin lineages from Viral AI")
parser.add_argument("output", type=str, help="<output> file to write combined CSV (.gz)")
args = parser.parse_args()

# import Pangolin results
pangolin_alias = {}
pangolin_raw = {}
rows = csv.DictReader(open(args.lineages))
for row in rows:
    pangolin_alias.update({row['isolate']: row['lineage']})
    pangolin_raw.update({row['isolate']: row['rawlineage']})

# handle gzip file if indicated by filename extension
if args.metadata.endswith('.gz'):
    handle = gzip.open(args.metadata, 'rt')
else:
    handle = open(args.metadata)

rows = list(csv.DictReader(handle, delimiter='\t'))
for row in rows:
    label = row["fasta header name"]
    lineage = pangolin_raw.get(label, None)
    if lineage is None:
        print(f"ERROR: Failed to retrieve Pangolin output for {label}")
    else:
        row.update({'rawlineage': lineage})
        row.update({'lineage': pangolin_alias.get(label, None)})

fieldnames = list(rows[0].keys())
outfile = gzip.open(args.output, 'wt')
writer = csv.DictWriter(outfile, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
writer.writeheader()
writer.writerows(rows)
