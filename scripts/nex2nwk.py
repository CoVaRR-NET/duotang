import re
import argparse
from Bio import Phylo
from io import StringIO
import sys
sys. setrecursionlimit(100000)

parser = argparse.ArgumentParser("Convert Treetime NEXUS to Newick file")
parser.add_argument("infile", type=str, help="input, NEXUS file")
parser.add_argument("outfile", type=argparse.FileType('w'), help="output, NEWICK file")
args = parser.parse_args()

"""
TreeTime stacks a lot of information to internal nodes of the tree:
NODE_0009060:0.00000[&date=2021.82]
The purpose of this script is to remove the comment fields.
"""

pat = re.compile('\[&U\]|\[&mutations="[^"]*",date=[0-9]+\.[0-9]+\]')
nexus = ''
for line in open(args.infile):
    nexus += pat.sub('', line)

# read in tree to prune problematic tips
phy = Phylo.read(StringIO(nexus), format='nexus')

for node in phy.get_terminals():
    node.comment = None

for node in phy.get_nonterminals():
    if node.name is None and node.confidence:
        node.name = node.confidence
        node.confidence = None
    node.comment = None

Phylo.write(phy, file=args.outfile, format='newick')
