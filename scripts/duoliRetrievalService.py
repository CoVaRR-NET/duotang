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

    parser.add_argument("--ts", type=str,
                        help="the thread id")
    parser.add_argument("--channel", type=str, default="C046T5JA48H",
                        help="Specify the channel that command applies to, default: pillar6-duotang_github")

    args = parser.parse_args()
    
    
    if not (os.path.exists("../.secret/duolioauthtoken") and os.path.exists("../.secret/duoliapptoken")):
        print ("This script reqires the oauth token and app token for duoli to be placed in .secret/duolioauthtoken and .secret/duoliapptoken")
        print ("Please check that they exist and the tokens are valid.")
        print ("Remeber to not push them into git.")
        sys.exit("token not found.")

    with open ("../.secret/duolioauthtoken", 'r') as fh:
        authToken = fh.readline().strip()
    with open ("../.secret/duoliapptoken", 'r') as fh:
        appToken = fh.readline().strip()

    app = App(token=authToken)
    client = WebClient(token=authToken)
    
    channelID = args.channel
    ts = "1682968319.934699" #args.ts
    rebuildCount = 0
    try:
        # Call the conversations.list method using the WebClient
        threadMessage = client.conversations_replies(channel=channelID, ts=ts)
        for msg in threadMessage.data["messages"]:
            if (msg["text"].find("<@U04R5U03V46>") != -1):
                #duoli was tagged in this message
                if (msg["text"].find("/update") != -1):
                    rebuildCount = rebuildCount + 1
                elif (msg["text"].find("/currentsituation") != -1):
                    text = msg["text"].replace("<@U04R5U03V46> /currentsituation\n", "")
                    #format the text a bit
                    text = text.replace("**Current Situation:**", "").replace("*", "**").replace("•", "*").replace("_*","*").replace("*_","*").replace("\n","\n\n")
                    text = text.split("\n")
                    for i in range(len(text)):
                        try:
                            if text[i-1][:2] == "* " and text[i+1][:2] == "* ":
                                del text[i]
                                i = i - 1
                        except:
                            pass

                    with open("currentsituation.md", "w+") as fh:
                        fh.write("\n".join(text))
    except SlackApiError as e:
        print(f"Error: {e}")
    
    print(rebuildCount)