

def openlineageNotes(file):
    dic={}
    with open (file, 'r') as f:
        f.readline()
        for i in f:
            dic[i.split('\t')[0]]=i.split('\t')[1].strip()
    return dic


AllLineageNotes=openlineageNotes("/lustre06/project/6065672/shared/covid-19/CAMEO/duotang/data_needed/lineageNotes.tsv")
UsedLineageNotes={}

def AnnotateParagraph(text):
    for i in text.split(' '):
        if i in AllLineageNotes:
            text=text.replace(i,"<u id='"+i+"'>"+i+"</u>")
            UsedLineageNotes[i]=AllLineageNotes[i]
    return text



def AddAllUsedTooltipElements():
    s="```{r, echo=FALSE}\n"
    print()
    for i in UsedLineageNotes:
        s+="tippy::tippy_this(elementId = \""+i+"\", tooltip = \""+UsedLineageNotes[i]+"\")\n"
    s+="```\n"
    return s


text="la la la BA.2"
text2="la la la BA.2.86 lala XBB"
text=AnnotateParagraph(text)
text2=AnnotateParagraph(text2)
print(text)
print(text2)
print(AddAllUsedTooltipElements())