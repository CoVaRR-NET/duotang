import argparse
from datetime import datetime
import lzma
import gzip
import csv


def progress(msg):
    timestamp = datetime.now().isoformat()
    print("[{}] {}".format(timestamp, msg))


def load_metadata(path, limit=100):
    """
    Load metadata from gzip-compressed CSV file and sort by lineage and week of sample
    collection for subsequent down-sampling.
    :param path:  str, absolute or relative path to TSV file
    :return:  dict, accession numbers keyed by lineage and week of sample collection
    """
    handle = gzip.open(path, 'rt')
    metadata = {}
    rows = csv.DictReader(handle)
    for count, row in enumerate(rows):
        lineage = row["lineage"]
        if lineage not in metadata:
            metadata.update({lineage: {}})

        # parse collection date
        try:
            dt = datetime.strptime(row["sample collection date"], "%Y-%m-%d")
        except ValueError:
            # skip records with incomplete collection dates
            continue

        yearweek = (dt.year, dt.isocalendar().week)
        if yearweek not in metadata[lineage]:
            metadata[lineage].update({yearweek: []})
        metadata[lineage][yearweek].append(row["fasta header name"])
        if count > limit:
            break

    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser("Down-sample genome data in xz-compressed file and "
                                     "output reference-aligned sequences.")

    parser.add_argument("infile", help="input, xz-compressed FASTA file from virusseq.py")
    parser.add_argument("metadata", help="input, gz-compressed metadata file from pango2seq.py")

    args = parser.parse_args()
    metadata = load_metadata(args.metadata)


