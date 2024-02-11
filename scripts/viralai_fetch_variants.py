import pandas as pd
import argparse
# Import the dnastack-client-library library
from dnastack import CollectionServiceClient
from dnastack.configuration import ServiceEndpoint


    # Create the client
api_url = 'https://viral.ai/api/'
client = CollectionServiceClient.make(ServiceEndpoint(adapter_type="collections", url=api_url))

# Get the Data Connect client for a specific collection
collection_name = 'virusseq'
data_connect_client = client.get_data_connect_client(collection_name)

# Dowload fasta files information
query = "SELECT * FROM \"collections\".\"virusseq\".\"variants\""
seq_df = pd.DataFrame(data_connect_client.query(query))
seq_df.to_csv("variants.tsv", sep = '\t', index = False)
