import argparse
import csv
import gzip
import sys

parser = argparse.ArgumentParser("Append Pangolin outputs to VirusSeq metadata")
parser.add_argument("metadata", type=str, help="<input> VirusSeq metadata TSV file (can be .gz)")
parser.add_argument("pangolin_csv", type=str, help="<input> Pangolin output CSV")
parser.add_argument("output", type=str, help="<output> file to write combined CSV (.gz)")
args = parser.parse_args()

# import Pangolin results
pangolin = {}
rows = csv.DictReader(open(args.pangolin_csv))
for row in rows:
    pangolin.update({row['taxon']: row})

# handle gzip file if indicated by filename extension
if args.metadata.endswith('.gz'):
    handle = gzip.open(args.metadata, 'rt')
else:
    handle = open(args.metadata)

rows = list(csv.DictReader(handle, delimiter='\t'))
for row in rows:
    label = row["fasta header name"]
    lineage = pangolin.get(label, None)
    if lineage is None:
        print(f"ERROR: Failed to retrieve Pangolin output for {label}")
        sys.exit()
    row.update(lineage)

fieldnames = list(rows[0].keys())
outfile = gzip.open(args.output, 'wt')
writer = csv.DictWriter(outfile, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
writer.writeheader()
writer.writerows(rows)
