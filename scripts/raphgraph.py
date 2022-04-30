#!/usr/bin/env python3

# code developed by Raphaël Poujol and Susanne Kraemer

from os import path
import sys
import csv

import numpy as np
import pandas as pd
import math


# colors of the different mutations
label_color = {
    'A>C': 'gold', 'A>G': 'silver', 'A>T': 'mediumpurple',
    'C>A': 'limegreen', 'C>G': 'violet', 'C>T': 'dodgerblue',
    'G>A': 'mediumblue', 'G>C': 'fuchsia', 'G>T': 'forestgreen',
    'T>A': 'indigo', 'T>C': 'dimgrey', 'T>G': 'darkorange',
    'missing': 'black'
}

genes = {
    266: ('ORF1ab', 21555),
    21563: ('Spike', 25384),
    25393: ('ORF3a', 26220),
    26245: ('E', 26472),
    26523: ('M', 27191),
    27202: ('ORF6', 27387),
    27394: ('ORF7a', 27759),
    27756: ('ORF7b', 27887),
    27894: ('ORF8', 28259),
    28274: ('N', 29533),
    29558: ('ORF10', 29674)
}


def load_mut_names(handle):
    """ dictionary to label each mutation """
    nucsub_AAname = {}
    for i, (nuc, AA) in pd.read_csv(handle, sep="\t", header=None).iterrows():
        if AA[0] == AA[-1]:
            AA = ""  # do not name synonymous mutations
        nucsub_AAname[nuc] = AA
    return nucsub_AAname
            

def import_tables(inputfiles):
    """
    Create a list of panda table containing all the numbers for each of the 29903 positions
    :param inputfiles:  list of paths to .var files
    :return:  list of pd.DataFrame objects
    """
    tablelist = []
    for file in inputfiles:
        if path.exists(file):
            t = pd.read_csv(file, sep="\t")
            n_sample = sum(t.iloc[0][["A", "C", "G", "T", "."]])
            if n_sample == 0:
                print("NO SAMPLE IN FILE : "+file)
                return None
            tablelist.append(t)
        else:
            print("ERROR NO SUCH FILE : "+file)
            return None
    return tablelist


def get_positions(tablelist, percent_min=0, add_missing=False):
    """
    Loop through the tables and keep only the positions where an alternative
    allele represent more than min% of the total number of samples
    :param tablelist:  list of pd.DataFrame objects from openfiles()
    :param percent_min:  minimum percentage to keep
    :param add_missing:
    :return:  list
    """
    totalposlist = []
    for t in tablelist:
        # absolute minimum number of sample
        n_min = math.ceil(percent_min / 100 * sum(t.iloc[0][["A", "C", "G", "T", "."]]))
        # for each possible reference allele :
        totalposlist += list(t[(t["REF"] == "A") & ((t["C"] >= n_min) | (t["G"] >= n_min) |
                                                    (t["T"] >= n_min))].index)
        totalposlist += list(t[(t["REF"] == "C") & ((t["A"] >= n_min) | (t["G"] >= n_min) |
                                                    (t["T"] >= n_min))].index)
        totalposlist += list(t[(t["REF"] == "G") & ((t["C"] >= n_min) | (t["A"] >= n_min) |
                                                    (t["T"] >= n_min))].index)
        totalposlist += list(t[(t["REF"] == "T") & ((t["C"] >= n_min) | (t["G"] >= n_min) |
                                                    (t["A"] >= n_min))].index)
        if add_missing:
            totalposlist += list(t[t["."] >= n_min].index)
    totalposlist = np.unique(totalposlist)
    totalposlist.sort()
    return totalposlist


def bighist(tablelist, poslist, y_names, min_val_AAlabel=15):
    """
    Generate histogram data
    :param tablelist:  list of pd.DataFrame objects
    :param poslist:  list, positions to report
    :param y_names:  list, filenames
    :param min_val_AAlabel:  int, cutoff to output
    :return:
    """
    for i, tab in enumerate(tablelist):
        nb_sample = sum(tab.iloc[0][["A", "C", "G", "T", "."]])

        all_pos_toplot = tab.iloc[poslist]
        missingvalues = all_pos_toplot["."] / nb_sample * 100

        # loop over all 12 substitutions:
        for ref in ["A", "C", "G", "T"]:
            for alt in [a for a in ["A", "C", "G", "T"] if a != ref]:
                values = all_pos_toplot[alt].copy()
                # set to 0 the alt numbers for the others ref alleles
                values[all_pos_toplot['REF'] != ref] = 0
                values = values/nb_sample*100
                if sum(values) > 0:
                    for j in range(len(values)):
                        if values.iloc[j] > min_val_AAlabel:
                            pos = all_pos_toplot.iloc[j]["POS"]
                            idx = pos.astype(str)+ref+">"+alt
                            print(namelist[i], j, values.iloc[j], nucsub_AAname.get(idx, ""))


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser("generate plot of mutation frequencies")
    parser.add_argument("--mutnames", default="data_needed/raphgraph/Mut_Nuc_AA_ORF.dic",
                        help="Path to file containing map of nucleotide to amino acid "
                             "mutations")
    parser.add_argument("-p", "--prefix", default="data_needed/raphgraph/msa_0327_",
                        help="Path to .var files to process")
    parser.add_argument("--pmin", default=75, help="percent of alt alleles to add mutation label")
    parser.add_argument("--outfile", type=str, help="file to write image to",
                        default="raphgraph.png")
    parser.add_argument("--min-val-label", type=int, default=15,
                        help=" % of alt alleles to add amino acide label")
    parser.add_argument("--add-missing", action="store_true", help="Add missing positions?")
    args = parser.parse_args()

    # File containing label
    # Default is AminoAcid labels for non synonymous mutations
    nucsub_AAname = load_mut_names(args.mutnames)
    
    namelist = ["Canada.BA.1", "final.BA.1", "Canada.BA.1.1", "final.BA.1.1",
                "Canada.BA.2", "final.BA.2", "final.BA.3"]
    pathlist = [args.prefix+i+".var" for i in namelist]

    namelist = [i.replace("_", "\n") for i in namelist]
    tablelist = import_tables(pathlist)
    
    poslist = get_positions(tablelist, percent_min=args.pmin, add_missing=args.add_missing)
    poslist = [i for i in poslist if 50 < i < 29950]
    bighist(tablelist, poslist, namelist, min_val_AAlabel=args.min_val_label)

