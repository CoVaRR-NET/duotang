

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

possible_string_before_lineage=[" ", "(", "\n", "**"]
possible_string_after_lineage=[" ", ")", "\n", ",", ". ", ".\n", "**"]

def AnnotateParagraph(text):
    def subReplace(i,text):
        if i not in UsedLineageNotes:
            UsedLineageNotes[i]=AllLineageNotes[i]
            inodot=i.replace(".","_")
            for c_b in possible_string_before_lineage:
                for c_a in possible_string_after_lineage:
                    text=text.replace(c_b+i+c_a,c_b+"<u id='"+inodot+"'>"+i+"</u>"+c_a)
        return(text)
    textnopunct=text
    for i in set(possible_string_before_lineage+possible_string_after_lineage):
      textnopunct=textnopunct.replace(i,' ')
    for i in textnopunct.split(' '):
        if i in AllLineageNotes:
            text=subReplace(i,text)
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
