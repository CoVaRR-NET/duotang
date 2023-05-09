import sys
import argparse
import json
import re
import subprocess
from dateutil.parser import parse
import uuid

if __name__ == "__main__":
    result = subprocess.run(["dnastack", "collections", "list"], stdout=subprocess.PIPE).stdout.decode('utf-8')

    payload = json.loads(result)
    #find the virusseq slugName
    virusseq = [child for child in payload if child['slugName']=='virusseq']
    description = virusseq[0]['description']
    information = re.split('<|>|;',description[description.find('Release:'):])
    

    def is_date(string, fuzzy=True):
        """
        Return whether the string can be interpreted as a date.

        :param string: str, string to check for date
        :param fuzzy: bool, ignore unknown tokens in string if True
        """
        try: 
            parse(string, fuzzy=fuzzy)
            return True

        except ValueError:
            return False

    date = None
    for item in information:
        if (is_date(item)):
            date = item


    def is_valid_uuid(val):
        try:
            uuid.UUID(str(val))
            return True
        except ValueError:
            return False

    identifier = None
    for item in information:
        if (is_valid_uuid(item)):
            identifier = item

    print (date + ";" + identifier)

    
    