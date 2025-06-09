import pandas as pd
import argparse
import sys
import numpy as np

#read in the alias tsv.
def aliasTsvToDictionary(aliasPath):
    aliasDictionary = {}
    with open (aliasPath, "r") as file:
        for line in file:
            short = line.split("\t")[0].strip()
            long = line.split("\t")[1].strip()
            aliasDictionary[short] = long
    return aliasDictionary    

def main():
    parser = argparse.ArgumentParser(description='Cleans up the downloaded GSD metadata.tar.xz by removing non-Canadian sequences and populate the required columns for downstream analysis. ')
    parser.add_argument("--metadata", type=str, help="Filepath to the GSD metadata tsv")
    parser.add_argument("--alias", type=str, help="Filepath to the pango_designation_alias_key.tsv")
    parser.add_argument("--out", type=str, help="FilePath to the output location")             

    args = parser.parse_args()
    
    # metadataPath = "data_needed/GSDmetadata.Canada.tsv"
    # AliasPath = "data_needed/pango_designation_alias_key.tsv"
    metadataPath = args.metadata
    AliasPath = args.alias

    metadata = pd.read_csv(metadataPath, header=None, sep="\t").iloc[:,[0,4,5, 6, 10, 11, 13]]
    metadata.columns = ["isolate_id", "gisaid_accession", "sample_collection_date", "location", "host_age", "host_gender", "lineage"]
    aliasKey = aliasTsvToDictionary(AliasPath)
    
    #breakdown the lineage group and append the full name to raw_lineage. 
    def map_lineage(row):
        parts = row["lineage"].split(".")
        first = parts[0]
        mapped = aliasKey.get(first, first)  # Use aliasKey if available, else keep original
        if len(parts) > 1:
            rest = ".".join(parts[1:])
            return mapped + "." + rest
        else:
            return mapped

    metadata["raw_lineage"] = metadata.apply(map_lineage, axis=1)

    # Backfill with original lineage where raw_lineage is empty or missing
    metadata['raw_lineage'] = metadata['raw_lineage'].fillna(metadata['lineage'])

    
    #break down the location column and isolate the province
    metadata["province"] = metadata["location"].str.split(" / ").str[2]

    #bin the ages
    metadata['age_numeric'] = pd.to_numeric(metadata['host_age'], errors='coerce')
    bins = np.arange(0, 110, 10) 
    labels = [f"{i}-{i+9}" for i in bins[:-1]]
    metadata['host_age_bin'] = pd.cut(metadata['age_numeric'], bins=bins, labels=labels, right=False)
    metadata['host_age_bin'] = metadata['host_age_bin'].cat.add_categories(['unknown'])
    metadata.loc[metadata['age_numeric'].isna(), 'host_age_bin'] = 'unknown'

    #append a faster_header name column
    metadata['fasta_header_name'] = metadata["isolate_id"]

    #append purpose of sample
    metadata['purpose_of_sampling'] = "Unknown"

    #append purpose of sequencing
    metadata['purpose_of_sequencing'] = "Unknown"

    #append sample_collected_by
    metadata['sample_collected_by'] = "Unknown"

    metadata.to_csv(args.out, index=False, sep="\t")

if __name__ == '__main__':
    main()
