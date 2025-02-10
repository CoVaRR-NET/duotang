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
    parser.add_argument("--messagefile", type=str, default=None,
                        help="The filepath for a text file to be sent as the message")
    parser.add_argument("--channel", type=str, default="C088LULD5PY",
                        help="Specify the channel that the message should be sent to, default: pillar6-duotang_github")
    parser.add_argument("--thread", type=str, default=None,
                        help="Specify the thread that the message should be sent to")

    args = parser.parse_args()
    
    #old covarrnet channel: C046T5JA48H
    
    if not (os.path.exists(".secret/duolioauthtoken") and os.path.exists(".secret/duoliapptoken")):
        print ("This script reqires the oauth token and app token for duoli to be placed in .secret/duolioauthtoken and .secret/duoliapptoken")
        print ("Please check that they exist and the tokens are valid.")
        print ("Remeber to not push them into git.")
        sys.exit("token not found.")

    with open (".secret/duolioauthtoken", 'r') as fh:
        authToken = fh.readline().strip()
    with open (".secret/duoliapptoken", 'r') as fh:
        appToken = fh.readline().strip()
        #appToken is used for websocket connections, NOT USED CURRENTLY

    app = App(token=authToken)
    client = WebClient(token=authToken)
    
    channel_id = args.channel
    fileList = args.file
    message_filepath = args.messagefile
    threadTS = args.thread
    
    if (message_filepath != None):
        with open (message_filepath, 'r') as fh:
            message_text = fh.read()
    else:
        message_text = args.message
    
    #filesJson = []
    #for file in files:
    #    filesJson.append({"file": file, "title":os.path.basename(file)})
    
    #filesJsonString=json.dumps(filesJson)
    #print(filesJsonString)
    ts = 0
    try:
        if (len(fileList) >0):
            for file in fileList:
                upload=client.files_upload_v2(file=file,filename=file)
                message_text=message_text+" <"+upload['file']['permalink']+"| > "
            #print(message_text)
            if (threadTS != None):
                response = client.chat_postMessage(channel=channel_id,text=message_text, thread_ts=threadTS)
            else:
                response = client.chat_postMessage(channel=channel_id,text=message_text)
            #response = client.files_upload_v2(channel=channel_id,initial_comment=message_text,file_uploads=filesJson)
        else:
            if (threadTS != None):
                response = client.chat_postMessage(channel=channel_id,text=message_text, thread_ts=threadTS)
            else:
                response = client.chat_postMessage(channel=channel_id,text=message_text)

        ts = response['ts']
    except SlackApiError as e:
        print("Error sending message: {}".format(e))

    print(ts)