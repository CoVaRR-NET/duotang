

AllLineageNotes={}
with open ("./data_needed/lineageNotes.tsv", 'r') as f:
    f.readline()
    for i in f:
        if len(i)>3:
            AllLineageNotes[i.split('\t')[0]]=i.split('\t')[1].strip()


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

    newtext=AnnotateParagraph(currentsituation)

    with open("currentsituation.md", "w") as fh:
        fh.write(newtext)
    CreateTooltipRMD()



AddToolTip()
