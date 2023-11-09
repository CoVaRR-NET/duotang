#!/bin/bash

python scripts/UpdateStatusManager.py --action set --key Approved --value "True"
python scripts/UpdateStatusManager.py --action set --key LastUpdated --value "2022-11-11"
python scripts/UpdateStatusManager.py --action set --key LastVirusSeqReleaseID --value "FFFFF"
python scripts/UpdateStatusManager.py --action set --key FailedCounter --value "0"
rm -f checkpoint