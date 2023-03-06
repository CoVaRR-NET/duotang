#since this isnt a constant connection bot, we dont need to run things async. For now, lets initialize as an slack_bolt.App rather than .AsyncApp.
#this drops the async libraries required to reduce the amount of dependencies we need.
#requires pip packages slack-bolt
import os
import argparse
import sys
#import json
from slack_bolt import App
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
#in fact, we dont even need to use socketmode, we dgaf about listening to events for now. 
#from slack_bolt.adapter.socket_mode import SocketModeHandler


if __name__ == "__main__":
    parser = argparse.ArgumentParser("Duoli - Duotang's slack integration.")

    parser.add_argument("--message", type=str, 
                        help="The message to be sent")
    parser.add_argument("--file",action='extend', nargs="+",  default=[],
                        help="path to the file to be uploaded, can specify multiple")
    parser.add_argument("--channel", type=str, default="C046T5JA48H",
                        help="Specify the channel that the message should be sent to, default: pillar6-duotang_github")

    args = parser.parse_args()
    
    
    if not (os.path.exists(".secret/duolioauthtoken") and os.path.exists(".secret/duoliapptoken")):
        print ("This script reqires the oauth token and app token for duoli to be placed in .secret/duolioauthtoken and .secret/duoliapptoken")
        print ("Please check that they exist and the tokens are valid.")
        print ("Remeber to not push them into git.")
        sys.exit("token not found.")

    with open (".secret/duolioauthtoken", 'r') as fh:
        authToken = fh.readline().strip()
    with open (".secret/duoliapptoken", 'r') as fh:
        appToken = fh.readline().strip()

    app = App(token=authToken)
    client = WebClient(token=authToken)
    
    channel_id = args.channel
    message_text = args.message
    files = args.file
    
    filesJson = []
    for file in files:
        filesJson.append({"file": file, "title":os.path.basename(file)})
    
    #filesJsonString=json.dumps(filesJson)
    #print(filesJsonString)
    
    try:
        if (len(files) >0):
            response = client.files_upload_v2(channel=channel_id,initial_comment=message_text,file_uploads=filesJson)
        else:
            response = client.chat_postMessage(channel=channel_id,text=message_text)
        print(response)
    except SlackApiError as e:
        print("Error sending message: {}".format(e))

