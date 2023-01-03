import pandas as pd
import argparse
# Import the dnastack-client-library library
from dnastack import CollectionServiceClient
from dnastack.configuration import ServiceEndpoint

def parse_args():
    parser = argparse.ArgumentParser(
        description='Downlaod info for multifasta file hosted at ViralAi')
    parser.add_argument('--seq', type=str, default=None,
                        help='seq file')

    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    # Create the client
    api_url = 'https://viral.ai/api/'
    client = CollectionServiceClient.make(ServiceEndpoint(adapter_type="collections", url=api_url))

    # Get the Data Connect client for a specific collection
    collection_name = 'virusseq'
    data_connect_client = client.get_data_connect_client(collection_name)

    # Dowload fasta files information
    query = "SELECT * FROM viralai.virusseq.files WHERE NAME LIKE '%multifasta_compressed%'"
    seq_df = pd.DataFrame(data_connect_client.query(query))
    seq_df = seq_df.sort_values(by='created_time', ascending=False)
    seq_df.head(1).to_csv(args.seq, encoding='utf-8', index=False, sep='\t', header=False, columns=["drs_url"])
