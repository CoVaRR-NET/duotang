"""
Extract nucleotide frequencies per aligned site for all genomes of a
given lineage in xz-compressed FASTA input.
"""

import argparse
import lzma
import gzip
import csv
import sys
import subprocess
import re
from alignment import iter_fasta, batcher


def filter_fasta(handle, headers):
    """
    Parse open file as FASTA.  Returns a generator
    of handle, sequence tuples.
    :param handle:  file, open stream to FASTA file in read mode
    :param headers:  dict, headers to keep
    :yield tuples, (header, sequence)
    """
    h, sequence = None, ''
    for line in handle:
        if line.startswith('>'):
            if len(sequence) > 0:
                if h in headers:
                    yield h, sequence
                sequence = ''
            h = line.lstrip('>').rstrip()
        else:
            sequence += line.strip().upper()
    if h in headers:
        yield h, sequence  # handle last record


def get_headers(path, lineage, lineage_field='rawlineage', header_field="fasta header name",
                delimiter=','):
    """
    Load metadata from gzip-compressed CSV file and extract FASTA headers
    for samples of a given lineage.
    :param path:  str, absolute or relative path to TSV file
    :param lineage:  str, PANGO lineage
    :param lineage_field:  str, fieldname for PANGO lineage
    :param header_field:  str, fieldname for sequence name (header)
    :param delimiter:  str, field separating character
    :return:  dict, fasta header names, no values
    """
    handle = gzip.open(path, 'rt')
    result = {} 
    l=len(lineage)
    for row in csv.DictReader(handle, delimiter=delimiter):
        if row[lineage_field][:l] != lineage:
            continue
        result.update({row[header_field]: None})
    return result


def aligner(batcher, refpath, path='minimap2', nthread=3):
    """
    Wrapper function for minimap2.
    :param batcher:  generator, from batcher()
    :param refpath:  str, path to FASTA with reference sequence(s)
    :param path:  str, path to binary executable
    :param nthread:  int, number of threads for parallel execution of minimap2
    :yield:  tuple, (header, reference position, CIGAR, unaligned sequence)
    """
    for stdin in batcher:
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
            rpos = int(rpos) - 1  # convert to 0-index
            yield qname, rpos, cigar, seq


def count_bases(iter, reflen):
    """
    Count nucleotides and gaps in aligned sequences streamed from
    minimap2.
    :param iter:  generator, aligner()
    :param reflen:  int, length of reference genome
    :return:  list of dicts, counts keyed by nucleotide or '.'; list
              index corresponds to genome position
    """
    counts = [dict([(a, 0) for a in 'ACGT.']) for _ in range(reflen)]
    for qname, rpos, cigar, seq in iter:
        for i in range(rpos):
            counts[i]['.'] += 1  # incomplete on left
        left = 0  # index for query
        tokens = re.findall(r'  (\d+)([MIDNSHPX=])', cigar, re.VERBOSE)
        for length, operator in tokens:
            length = int(length)
            substr = seq[left:(left + length)]
            if operator in ['X', '=']:
                for i, nt in enumerate(substr):
                    counts[rpos+i][nt if nt in 'ACGT' else '.'] += 1
                left += length
                rpos += length
            elif operator in ['S', 'I']:
                left += length  # discard soft clip / ignore insertion
            elif operator == 'D':
                # deletion relative to reference
                for i in range(rpos, rpos+length):
                    counts[i]['.'] += 1
                rpos += length
            elif operator == 'H':
                # hard clip, do nothing
                pass
            else:
                print("ERROR: unexpected operator {}".format(operator))
                sys.exit()
        # note rpos is now at end of sequence
        for i in range(rpos, reflen):
            counts[i]['.'] += 1  # incomplete on right
    return counts


if __name__ == "__main__":
    # command-line interface
    import codecs

    def unescaped_str(arg_str):
        return codecs.decode(str(arg_str), 'unicode_escape')

    parser = argparse.ArgumentParser("Extract nucleotide frequencies for all genomes "
                                     "of a given lineage.")

    parser.add_argument("infile", type=str, help="input, xz-compressed FASTA file")
    parser.add_argument("lineage", type=str, help="PANGO lineage designation")
    parser.add_argument("metadata", type=str, help="input, gz-compressed CSV file with PANGO lineages")
    parser.add_argument("outfile", type=argparse.FileType('w'),
                        help="output, path to write TSV file of nucleotide frequencies")

    parser.add_argument("--reffile", type=str, default="data_needed/NC_045512.fa",
                        help="optional, path to reference genome FASTA")
    parser.add_argument("--limit", type=int, default=5000,
                        help="optional, maximum tolerance for gaps due to misalignment "
                             "(default 5000)")
    parser.add_argument("--seqname", type=str, default="fasta header name",
                        help="optional, fieldname for headers to link sequences between "
                             "FASTA and metadata files")
    parser.add_argument("--pango", type=str, default="lineage",
                        help="optional, fieldname for PANGO lineage in metadata")
    parser.add_argument("--delimiter", type=unescaped_str, default=",",
                        help="optional, delimiter for metadata file")

    args = parser.parse_args()

    with open(args.reffile) as handle:
        header, refseq = next(iter_fasta(handle))
        reflen = len(refseq)

    headers = get_headers(args.metadata, lineage=args.lineage, lineage_field=args.pango,
                          header_field=args.seqname, delimiter=args.delimiter)
    if len(headers) == 0:
        print(f"ERROR: Metadata does not contain any samples of lineage {args.lineage}.")
        sys.exit()

    handle = lzma.open(args.infile, 'rt')
    batcher = batcher(filter_fasta(handle, headers))
    aligned = aligner(batcher, refpath=args.reffile)
    counts = count_bases(aligned, reflen=reflen)

    # write results to file
    writer = csv.DictWriter(args.outfile, delimiter='\t',
                            fieldnames=['POS', 'REF', 'A', 'C', 'G', 'T', '.'])
    writer.writeheader()
    for i, row in enumerate(counts):
        row.update({'POS': i+1, 'REF': refseq[i]})  # 1-index
        writer.writerow(row)
