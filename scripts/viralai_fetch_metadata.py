import pandas as pd
import argparse
from datetime import datetime

# Import the dnastack-client-library library
from dnastack import CollectionServiceClient
from dnastack.configuration import ServiceEndpoint
import re


def parse_args():
    parser = argparse.ArgumentParser(
        description='Download metadata from ViralAi')
    parser.add_argument('--alias', type=str, default=None,
                        help='.tsv file')
    parser.add_argument('--csv', type=str, default=None,
                        help='.csv file')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()

    # Create the client
    api_url = 'https://viral.ai/api/'
    client = CollectionServiceClient.make(ServiceEndpoint(
        adapter_type="collections", url=api_url))

    # Get the Data Connect client for a specific collection
    collection_name = 'virusseq'
    data_connect_client = client.get_data_connect_client(
        collection_name)

    query = """SELECT * FROM collections.virusseq.public_samples"""
    df = pd.DataFrame(data_connect_client.query(query))

    if not df['gisaid_accession'].is_unique():
        df.to_csv(args.csv.replace("metadata.tsv",
                                   "gisaid_duplicates.tsv"),
                  encoding='utf-8',
                  index=False,
                  sep='\t',
                  columns=df['gisaid_accession'])

    if not df['isolate'].is_unique():
        df.to_csv(args.csv.replace("metadata.tsv",
                                   "virusseq_duplicates.tsv"),
                  encoding='utf-8',
                  index=False,
                  sep='\t',
                  columns=df['isolate'])

    df['rawlineage'] = df['lineage']
    alias_df = pd.read_csv(args.alias, sep='\t', header=0)
    alias_dic = pd.Series(alias_df.lineage.values,
                          index=alias_df.alias).to_dict()
    df['rawlineage']=(df['rawlineage'].str.extract(r"([A-Z]+)",expand=False)
                                                            .map(alias_dic) + "." + df['rawlineage'].str.split(".",1).str[1]).fillna(df['rawlineage'])

    # Sort by sample_collection_date and write it to csv
    df.to_csv(args.csv, encoding='utf-8', index=False, sep='\t', compressio='gzip')
