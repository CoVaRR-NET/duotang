

AllLineageNotes={}
with open ("downloads/lineagesNotesAnnotated.tsv", 'r') as f:
    f.readline()
    for i in f:
        if len(i)>3:
            row = i.split('\t')
            lineage = row[0]
            parent="Ancestor:" + row[1] if row[1] != "NA" else ""
            description = row[2].strip()
            n120days = row[3].strip() + " samples in last 120 days."
            AllLineageNotes[i.split('\t')[0]]="//".join([parent, n120days, description]) if parent != "" else "//".join([n120days, description])


UsedLineageNotes={}

def AnnotateParagraph(text):
    def subReplace(i,text):
        if i not in UsedLineageNotes:
            UsedLineageNotes[i]=AllLineageNotes[i]
            inodot=i.replace(".","_")
            for c1 in [" ","(","\n"]:
                for c2 in [" ",")","\n",",",". ",".\n"]:
                    text=text.replace(c1+i+c2,c1+"<u id='"+inodot+"'>"+i+"</u>"+c2)
        return(text)
    for i in text.replace("\n"," ").replace("("," ").replace(","," ").split(' '):
        if i in AllLineageNotes:
            text=subReplace(i,text)
        if i!="" and (i[-1] in [".","*",".",")"]) and (i[:-1] in AllLineageNotes):
            text=subReplace(i[:-1],text)
    return text



def AddAllUsedTooltipElements():
    s="\n\n\n\n```{r, echo=FALSE}\n"
    for i in UsedLineageNotes:
        inodot=i.replace(".","_")
        s+="tippy::tippy_this(elementId = \""+inodot+"\", tooltip = \""+UsedLineageNotes[i]+"\")\n"
    s+="```\n"
    return s

def CreateTooltipRMD():
    with open("Tooltip.Rmd", "w") as fh:
        fh.write(AddAllUsedTooltipElements())

def AddToolTip():
    with open ("currentsituation.md", 'r') as f:
        currentsituation=f.read()
    if (currentsituation.find("<!-- edited -->") == -1):
        newtext=AnnotateParagraph(currentsituation)
        newtext = newtext + "\n\n\n<!-- edited -->"
        CreateTooltipRMD()
        with open("currentsituation.md", "w") as fh:
            fh.write(newtext)
    else:
        print("current situation already edited.")





AddToolTip()
