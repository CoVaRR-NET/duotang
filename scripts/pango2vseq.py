import argparse
import csv
import gzip
import sys

parser = argparse.ArgumentParser("Append Pangolin outputs to VirusSeq metadata")
parser.add_argument("metadata", type=str, help="<input> VirusSeq metadata TSV file (can be .gz)")
parser.add_argument("pangolin", type=str, help="<input> Pangolin output CSV")
parser.add_argument("output", type=str, help="<output> file to write combined CSV (.gz)")
args = parser.parse_args()

# import Pangolin results from Viral AI
pangolin = {}
rows = csv.DictReader(open(args.pangolin))
for row in rows:
    pangolin.update({row['isolate']: row['lineage']})

# handle gzip file if indicated by filename extension
if args.metadata.endswith('.gz'):
    handle = gzip.open(args.metadata, 'rt')
else:
    handle = open(args.metadata)

rows = csv.DictReader(handle, delimiter='\t')
fieldnames = list(rows.fieldnames) + ['lineage']

outfile = gzip.open(args.output, 'wt')
writer = csv.DictWriter(outfile, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
writer.writeheader()

for row in rows:
    label = row["isolate"]
    lineage = pangolin.get(label, None)
    if lineage is None:
        print(f"WARNING: Failed to retrieve lineage for {label}")
    row.update({'lineage': lineage})
    writer.writerow(row)

outfile.close()
handle.close()
