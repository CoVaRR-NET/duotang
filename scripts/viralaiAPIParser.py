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
    information = re.split('<|>|;|\(|\)|identifier:',description[description.find('Release:'):])
    

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
        if (is_date(item.strip())):
            date = item.strip().replace("&nbsp","")


    def is_valid_uuid(val):
        try:
            uuid.UUID(str(val))
            return True
        except ValueError:
            return False

    identifier = None
    for item in information:
        if (is_valid_uuid(item.strip())):
            identifier = item.strip().replace("&nbsp","")

    #sometimes the uuid is invalid for some reason e.g. missing a character. lets just be dumb about it and assign it something so the script can continue
    if identifier == None:
        information = re.split('<|>|;|\(|\)|identifier:',description[description.find('Release:'):])
        for item in information:
            if (item.count("-") == 4):
                identifier = item.strip().replace("&nbsp","")


    test = " ed3b55a-9096-48bd-95db-aed336055a8a".strip()
    test2 = "d141babd-b824-4f8b-a310-717be1f5144f"
    t2 = is_valid_uuid(test.strip())

    print (date + ";" + identifier)

    
    