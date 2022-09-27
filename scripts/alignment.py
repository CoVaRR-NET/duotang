import argparse
from datetime import datetime
import lzma
import gzip
import csv
import random
import subprocess
import re


def progress(msg):
    timestamp = datetime.now().isoformat()
    print("[{}] {}".format(timestamp, msg))


def iter_fasta(handle, sample=None):
    """
    Parse open file as FASTA.  Returns a generator
    of handle, sequence tuples.

    :param handle:  open stream to FASTA file in read mode
    :param sample:  dict, (lineage, coldate) keyed by sequence header

    :yield tuples, (header, sequence)
    """
    h, sequence = None, ''
    for line in handle:
        if line.startswith('>'):
            if len(sequence) > 0:
                if sample is None:
                    yield h, sequence
                elif h in sample:
                    lineage, coldate = sample[h]
                    h2 = f"{h}_{lineage}_{coldate}"
                    yield h2, sequence
                sequence = ''
            h = line.lstrip('>').rstrip()
        else:
            sequence += line.strip().upper()

    # handle last record
    if sample is None:
        yield h, sequence
    elif h in sample:
        lineage, coldate = sample[h]
        h2 = f"{h}_{lineage}_{coldate}"
        yield h2, sequence


def batcher(stream, size=100, maxn=2000, minlen=29000):
    """
    Break FASTA data into batches to stream to minimap2
    :param stream:  generator, (header, sequence) tuples from iter_fasta()
    :param size:  int, number of records to write as FASTA to stdin
    :param maxn:  int, maximum tolerance for uncalled bases ("N"s)
    :param minlen:  int, discard genomes with fewer base calls than this number
    """
    stdin = ''
    for i, record in enumerate(stream):
        qname, seq = record
        if len(seq) < minlen or seq.count('N') > maxn:
            continue
        stdin += '>{}\n{}\n'.format(qname, seq)
        if i > 0 and i % size == 0:
            yield stdin
            stdin = ''
    if stdin:
        yield stdin


def apply_cigar(seq, rpos, cigar, reflen):
    """
    Use CIGAR to pad sequence with gaps as required to
    align to reference.  Adapted from http://github.com/cfe-lab/MiCall
    :param seq:  str, unaligned sequence
    :param rpos:  int, position of first base in reference genome
    :param cigar:  str, CIGAR string
    :param reflen:  int, length of reference genome
    :return:  str, aligned sequence
    """
    # validate CIGAR string
    is_valid = re.match(r'^((\d+)([MIDNSHPX=]))*$', cigar)
    if not is_valid:
        raise RuntimeError('Invalid CIGAR string: {!r}.'.format(cigar))

    rpos = int(rpos) - 1  # convert to 0-index
    tokens = re.findall(r'  (\d+)([MIDNSHPX=])', cigar, re.VERBOSE)
    aligned = '-' * rpos
    left = 0
    for length, operation in tokens:
        length = int(length)
        if operation in 'M=X':
            aligned += seq[left:(left + length)]
            left += length
        elif operation == 'D':
            aligned += '-' * length
        elif operation in 'SI':
            left += length  # soft clip

    aligned += '-'*(reflen-len(aligned))  # pad on right
    return aligned


def minimap2(stdin, refpath, path='minimap2', nthread=3, reflen=29903):
    """
    Wrapper function for minimap2.

    :param infile:  file object or StringIO
    :param refpath:  str, path to FASTA with reference sequence(s)
    :param path:  str, path to binary executable
    :param nthread:  int, number of threads for parallel execution of minimap2
    :param minlen:  int, filter genomes below minimum length; to accept all, set to 0.
    :param reflen:  int, length of reference genome

    :yield:  tuple, header and aligned sequence
    """
    p = subprocess.Popen(
        [path, '-t', str(nthread), '-a', '--eqx', refpath, '-'], encoding='utf8',
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
    stdout, stderr = p.communicate(stdin)

    for line in stdout.split('\n'):
        if line == '' or line.startswith('@'):
            # split on \n leaves empty line; @ prefix header lines
            continue

        qname, flag, rname, rpos, _, cigar, _, _, _, seq = \
            line.strip('\n').split('\t')[:10]

        if rname == '*' or ((int(flag) & 0x800) != 0):
            # did not map, or supplementary alignment
            continue

        aligned = apply_cigar(seq, rpos, cigar, reflen)

        yield qname, aligned


def load_metadata(path):
    """
    Load metadata from gzip-compressed CSV file and sort by lineage and week of sample
    collection for subsequent down-sampling.
    :param path:  str, absolute or relative path to TSV file
    :return:  dict, (accession number, collection date) tuples keyed by lineage and
              week of sample collection
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
        
        #yearweek = (dt.year, dt.isocalendar().week)
       	yearweek = (dt.year, dt.isocalendar()[1])

        if yearweek not in metadata[lineage]:
            metadata[lineage].update({yearweek: []})
        metadata[lineage][yearweek].append(
            tuple([row["fasta header name"], row["sample collection date"]])
        )

    return metadata


def sampling(metadata, before, after, cutoff): #before=2, after=4, cutoff=(2022, 20)):
    """
    Random sampling of sequences (FASTA header name, collection date) by lineage
    and week of sample collection.

    :param metadata:  dict, from load_metadata()
    :param before:  int, max num. genomes to select for given lineage/week BEFORE cutoff
    :param after:  int, max number to select AFTER cutoff
    :param cutoff:  tuple, (year, week)
    :return:  list, dicts of (lineage, collection date) keyed by sequence name
    """
    result = {}
    for lineage, byweek in metadata.items():
        nsample=sum([len(byweek[i]) for i in byweek])
        if(max(byweek) > cutoff or nsample > 200):
            for yearweek, rows in byweek.items():
                sampsize = min(len(rows), before) if yearweek < cutoff else min(len(rows), after)
                sample = random.sample(rows, sampsize)
                for seqname, coldate in sample:
                    result.update({seqname: (lineage, coldate)})
        else:
            sampsize=int(nsample/100)+1
            all=[]
            for i in byweek:
                all.extend(byweek[i])
            sample = random.sample(all,sampsize)
            for seqname, coldate in sample:
                result.update({seqname: (lineage, coldate)})
    return result


def align(xzfile, refpath, sample, limit):
    """
    Pairwise alignment of genomes to reference sequence
    :param xzfile:  str, path to xz-compressed FASTA file
    :param refpath:  str, path to FASTA file containing reference genome
    :param sample:  dict, returned from sampling()
    :yield:  (str, str), (header, aligned sequence)
    """
    handle = lzma.open(xzfile, 'rt')
    stream = iter_fasta(handle, sample)  # filtered
    for batch in batcher(stream):
        for header, seq in minimap2(batch, refpath=refpath):
            if seq.count('-') > limit:
                #print(f"Rejecting poor quality alignment {header}")
                continue
            yield header, seq


if __name__ == "__main__":
    # command line interface
    parser = argparse.ArgumentParser("Down-sample genome data in xz-compressed file and "
                                     "output reference-aligned sequences.")

    parser.add_argument("infile", type=str,
                        help="input, xz-compressed FASTA file from virusseq.py")
    parser.add_argument("metadata", type=str,
                        help="input, gz-compressed metadata file from pango2seq.py")
    parser.add_argument("outfile", type=argparse.FileType('w'),
                        help="output, path to write FASTA file of aligned sample")

    parser.add_argument("--reffile", type=str, default="data_needed/NC_045512.fa",
                        help="optional, path to reference genome FASTA")
    parser.add_argument("--limit", type=int, default=5000,
                        help="optional, maximum tolerance for gaps due to misalignment "
                             "(default 5000)")
    parser.add_argument("--seed", type=int,
                        help="optional, set random seed for testing")

    parser.add_argument("--before", type=int, default=1,
                        help="int, number of genomes to sample per lineage "
                             "per week per province, before cutoff date")
    parser.add_argument("--after", type=int, default=1,
                        help="int, number of genomes to sample per lineage "
                             "per week per province, before cutoff date")
    parser.add_argument("--year", type=int, default=2022,
                        help="int, year number for cutoff date")
    parser.add_argument("--epiweek", type=int, default=15,
                        help="int, week number for cutoff date")

    args = parser.parse_args()
    if args.seed:
        random.seed(args.seed)

    with open(args.reffile) as handle:
        header, seq = next(iter_fasta(handle))
        reflen = len(seq)
        # write reference genome to file for outgroup rooting later
        args.outfile.write(f">reference\n{seq}\n")

    progress("loading metadata")
    metadata = load_metadata(args.metadata)

    progress("sampling records")
    sample = sampling(metadata, before=args.before, after=args.after, 
                      cutoff=(args.year, args.epiweek))

    progress(f"aligning {len(sample)} samples")
    aligner = align(args.infile, refpath=args.reffile, sample=sample, limit=args.limit)
    #aligner = align(args.infile, refpath=args.reffile, sample=None, limit=args.limit)
    for header, seq in aligner:
        args.outfile.write(f">{header}\n{seq}\n")

    progress("finished!")
