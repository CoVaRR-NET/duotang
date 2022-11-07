
###Construct the tree
makepangotree <- function(rawlineagelist){
  fulltree=list()
  addelement <- function(e){
    toadd=list()
    if(! e  %in% fulltree){
      toadd=list(e)
      n=e
      internalnode <- function(pathfromroot){
        return(fulltree[grepl(gsub("\\.", "\\\\.",pathfromroot),fulltree)] )
      }
      #find the first existing potential internal node 
      while(length(internalnode(n))==0 & n!=""){
        n=sapply(list(head((strsplit(n, "\\."))[[1]],-1)), paste, collapse = ".")
      }
      if(n!=""){
        bifurcation=paste(n,"*",sep="")
        if(! bifurcation %in% fulltree){
          toadd <- append(toadd,bifurcation)
        }
      }
    }
    return(toadd)
  }
  for(l in rawlineagelist){
    fulltree=append(fulltree,addelement(l))
  }
  return(fulltree)
}

getsublineagesfromnode <- function(x) {
  if(substr(x, nchar(x), nchar(x))!="*"){
    print("error getsublineagefromnode")
  }
  nostar=substr(x, 0, nchar(x)-1)
  togrep=gsub("\\.", "\\\\.",nostar)
  togrep=paste(togrep,"$|",togrep,".",sep="")
  l=unique(meta$lineage[grepl(togrep,meta$rawlineage)])
  if(length(l)>1){
    name=unique(meta$lineage[meta$rawlineage==nostar])
    if(length(name)!=0){
      name=paste(name[1],"*",sep="")
    }else{name=x}
    l=append(name,l)
  }
  return(l)
}

torawlineage <- function(x){
  y=unique(meta$rawlineage[meta$lineage==x])[1]
  if(length(y)!=0){
    r=y[1]
  }else{r=x}
  r
}
