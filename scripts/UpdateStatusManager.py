import os
import json
import argparse
import sys


#statuses = {
#    "LastUpdate" : "2023-03-15",
#    "LastVirusSeqRelease" : "2023-03-13",
#    "LastVirusSeqReleaseID" : "7eaddf91-7d9c-458f-815c-35d62c7fab18",
#    "LastViralAIUpdate" : "2023-03-15",
#    "LastNotifMessage" : "1234567890",
#    "Rebuild" : "False",
#    "Approved": "False"
#}

if __name__ == "__main__":
    parser = argparse.ArgumentParser("Script for editing the update status json file.")

    parser.add_argument("--key", type=str, default = "",
                        help="The key")
    parser.add_argument("--value", type=str, default = "",
                        help="The value")
    parser.add_argument("--action", type=str, default = "list", choices=['list','get','set'],
                        help="The value")             
    parser.add_argument("--file", type=str,  default="./DuotangUpdateStatus.json",
                        help="path to json file.")
    parser.add_argument("--new", action='store_true',
                        help="path to json file.")


    args = parser.parse_args()

    if os.path.exists(args.file):
        with open (args.file, 'r') as fh:
            jsonObj = json.load(fh)
    else:
        sys.exit("json file doesnt exist.")
    
    if (args.action == "list"):
        print(', '.join(jsonObj.keys()))
        sys.exit(0)

    if (args.action == "get"):
        if (args.key in jsonObj):
            print(jsonObj[args.key])
            sys.exit(0)
        else:
            sys.exit("Key doesnt exist, use --key argument.")
    
    if (args.action == "set" and not args.new):
        if (args.key in jsonObj):
            jsonObj[args.key] = args.value
            with open(args.file, 'w') as f:
                json.dump(jsonObj, f)
            sys.exit(0)
        else:
            sys.exit("Key doesnt exist. Use --new if you want to set a new field.")
    elif (args.action == "set" and args.new):
        jsonObj[args.key] = args.value
        with open(args.file, 'w') as f:
            json.dump(jsonObj, f)
        sys.exit(0)
