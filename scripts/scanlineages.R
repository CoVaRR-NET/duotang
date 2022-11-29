

### Create a dataframe containing all translation from the actual data contained in 'meta'
### Ordering is helping finding the nickname that make the final name as short as possible
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


###Construct the tree
makepangotree <- function(rawlineagelist){
  fulltree=list()
  addelement <- function(e){
    toadd=list()
    if(! e  %in% fulltree){
      toadd=list(e)
      #Function to check if an internal node is (1) a leaf (2)  abifurcation (3) already exist
      internalnode <- function(pathfromroot){
        togrep=paste(pathfromroot,"$|",pathfromroot,".|",pathfromroot,"\\*$",sep="")
        togrep=gsub("\\.", "\\\\.",togrep)
        return(fulltree[grepl(togrep,fulltree)] )
      }
      #find the first existing potential internal node 
      while(length(internalnode(e))==0 & e!=""){
        e=sapply(list(head((strsplit(e, "\\."))[[1]],-1)), paste, collapse = ".")
      }
      if(e!=""){
        bifurcation=paste(e,"*",sep="")
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

rawtoreallineage <- function(lineage){
  t=dico[sapply(dico$fullname,function(x){grepl(x,lineage)}),]
  if(nrow(t)>0){
    deduced=str_replace(lineage,t[1,"fullname"], t[1,"surname"])
    observed=meta[meta$rawlineage==lineage,][1,]$lineage
    if(! is.na(observed) && deduced!=observed){
      return(observed)
    }
    return(deduced)
  }
  return(lineage)
}


realtorawlineage <- function(lineage){
  #Since * could be directly add to the first part : eg BA*
  if(substr(lineage, nchar(lineage), nchar(lineage))=="*"){
    star="*"
    lineage=substr(lineage, 1, nchar(lineage)-1)
  }else{
    star=""
  }
  firstpart=strsplit(lineage, "\\.")[[1]][1]
  if(any(firstpart==dico$surname)){
    lineage=sapply(list(c(dico$fullname[dico$surname==firstpart],strsplit(lineage, "\\.")[[1]][-1])), paste, collapse = ".")
  }
  return(paste(lineage,star,sep=""))
}

getAllStrictoLineages <- function(){
  unique(meta$lineage)
}

getStrictoSubLineages <- function(x) {
  if(substr(x, nchar(x), nchar(x))!="*"){
    return(list(rawtoreallineage(x)))
  }else{
    raw=realtorawlineage(x)
    raw=substr(raw, 0, nchar(raw)-1) #remove star
    togrep=paste(raw,"$|",raw,".",sep="")
    togrep=gsub("\\.", "\\\\.",togrep)
    l=unique(meta$lineage[grepl(togrep,meta$rawlineage)])
    if(length(l)>1){
      l=append(rawtoreallineage(x),l)
    }
    return(l)
  }
}


getAllSubLineages <- function(x,tree) {
  if(substr(x, nchar(x), nchar(x))!="*"){
    return(list(rawtoreallineage(x)))
  }else{
    raw=realtorawlineage(x)
    raw=substr(raw, 0, nchar(raw)-1) #remove star
    togrep=paste(raw,"$|",raw,".",sep="")
    togrep=gsub("\\.", "\\\\.",togrep)
    l=tree[grepl(togrep,tree)]
    l=lapply(l,rawtoreallineage)
    if(length(l)>1){
      l=append(rawtoreallineage(x),l)
    }
    return(l)
  }
}

