

AllLineageNotes={}
with open ("./data_needed/lineageNotes.tsv", 'r') as f:
    f.readline()
    for i in f:
        AllLineageNotes[i.split('\t')[0]]=i.split('\t')[1].strip()


UsedLineageNotes={}

def AnnotateParagraph(text):
    def subReplace(i,text):
        if i not in UsedLineageNotes:
            UsedLineageNotes[i]=AllLineageNotes[i]
            for c1 in [" ","(","\n"]:
                for c2 in [" ",")","\n",",",". ",".\n"]:
                    text=text.replace(c1+i+c2,c1+"<u id='"+i+"'>"+i+"</u>"+c2)
        return(text)
    for i in text.replace("\n"," ").replace("("," ").split(' '):
        if i in AllLineageNotes:
            text=subReplace(i,text)
        if i!="" and (i[-1] in [".","*",".",")"]) and (i[:-1] in AllLineageNotes):
            text=subReplace(i[:-1],text)
    return text



def AddAllUsedTooltipElements():
    s="\n\n\n\n```{r, echo=FALSE}\n"
    print()
    for i in UsedLineageNotes:
        s+="tippy::tippy_this(elementId = \""+i+"\", tooltip = \""+UsedLineageNotes[i]+"\")\n"
    s+="```\n"
    return s


with open ("currentsituation.md", 'r') as f:
    currentsituation=f.read()

newtext=AnnotateParagraph(currentsituation)
newtext+=AddAllUsedTooltipElements()

print(newtext)
