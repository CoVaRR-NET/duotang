
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
  if(x=="*"){
    return(unique(meta$lineage))
  }
  if(substr(x, nchar(x), nchar(x))!="*"){
    print("error getsublineagefromnode")
  }else{
    nostar=substr(x, 0, nchar(x)-1)
  }
  firstpart=strsplit(nostar, "\\.")[[1]][1]
  if(any(firstpart==dico$surname)){
    nostar=sapply(list(c(dico$fullname[dico$surname==firstpart],strsplit(nostar, "\\.")[[1]][-1])), paste, collapse = ".")
  }
  togrep=paste(nostar,"$|",nostar,".",sep="")
  togrep=gsub("\\.", "\\\\.",togrep)
  l=unique(meta$lineage[grepl(togrep,meta$rawlineage)])
  if(length(l)>1){
    l=append(rawtoreallineage(x),l)
  }
  return(l)
}


rawtoreallineage <- function(l){
  t=dico[sapply(dico$fullname,function(x){grepl(x,l)}),]
  if(nrow(t>0)){
    l=str_replace(l,t[1,"fullname"], t[1,"surname"])
  }
  return(l)
}



makepangolindico <- function(){
  getdef <- function(x){
    raw=x[1]
    lin=x[2]
    fullname=sapply(list(strsplit(raw, "\\.")[[1]][1:(length(strsplit(raw, "\\.")[[1]])-length(strsplit(lin, "\\.")[[1]])+1)]), paste, collapse = ".")
    c(surname=strsplit(lin, "\\.")[[1]][1],fullname=fullname)
  }
  dico=as.data.frame(unique(t(sapply(as.data.frame(t(unique(meta[meta$rawlineage!=meta$lineage,c("rawlineage", "lineage")]))),getdef))))
  dico=dico[order(sapply(dico$fullname,nchar),decreasing=TRUE),]
  return(dico)
}

dico=makepangolindico()