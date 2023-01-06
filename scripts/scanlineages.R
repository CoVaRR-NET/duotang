

### Create a dataframe containing all translation from the actual data contained in 'meta'
### Ordering is helping finding the nickname that make the final name as short as possible
makepangolindico <- function(){
  getdef <- function(x){
    raw=x[1]
    lin=x[2]
    fullname=sapply(list(strsplit(raw, "\\.")[[1]][1:(length(strsplit(raw, "\\.")[[1]])-length(strsplit(lin, "\\.")[[1]])+1)]), paste, collapse = ".")
    c(surname=strsplit(lin, "\\.")[[1]][1],fullname=fullname)
  }
  dico=as.data.frame(unique(t(sapply(as.data.frame(t(unique(meta[meta$raw_lineage!=meta$lineage,c("raw_lineage", "lineage")]))),getdef))))
  dico=dico[order(sapply(dico$fullname,nchar),decreasing=TRUE),]
  return(dico)
}
dico=makepangolindico()


###Construct the tree
makepangotree <- function(raw_lineagelist){
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
  for(l in raw_lineagelist){
    fulltree=append(fulltree,addelement(l))
  }
  return(fulltree)
}


rawtoreallineage <- function(lineage) {
  # FIXME: dico should be passed as an argument, not an implicit global var
  sub.dico <- dico[sapply(dico$fullname, function(x) { grepl(x, lineage) } ), ]
  if (nrow(sub.dico)>0) {
    #deduced <- str_replace(lineage,t[1,"fullname"], t[1,"surname"])
    deduced <- gsub(sub.dico$fullname[1], sub.dico$surname[1], lineage)
    observed <- meta[meta$raw_lineage==lineage, ][1, ]$lineage
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
    lineage=sapply(list(c(dico$fullname[dico$surname==firstpart],
                          strsplit(lineage, "\\.")[[1]][-1])), paste, collapse = ".")
  }
  return(paste(lineage,star,sep=""))
}

getAllStrictoLineages <- function(meta) {
  unique(meta$lineage)
}


getStrictoSubLineages <- function(x, meta) {
  raw <- realtorawlineage(x)
  if (!endsWith(x, "*")) {
    return(list(rawtoreallineage(raw)))
  }
  else {
    raw <- substr(raw, 0, nchar(raw)-1)  # remove star
    # expand * to regular expression
    togrep <- paste(raw, "$|", raw, ".", sep="")
    togrep <- gsub("\\.", "\\\\.", togrep)  # handle escape chars
    l <- unique(meta$lineage[grepl(togrep, meta$raw_lineage)])
    if(length(l) > 1) {
      l <- append(rawtoreallineage(x), l)
    }
    return(l)
  }
}


getAllSubLineages <- function(x, tree) {
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

isSubLineage <- function(parent,child){
  raw_parent=realtorawlineage(parent)
  raw_child=realtorawlineage(child)
  if (endsWith(parent, "*")) {
    raw_parent=realtorawlineage(substr(parent, 1, nchar(parent)-1))
  }
  np=nchar(raw_parent)
  nextchar=substr(raw_child, np+1, np+1)
  return(substr(raw_child, 1, np)==raw_parent && nextchar %in% c(".","*",""))
}

#' create.pango.group
#' 
#' Generate PANGO group assignments based on each entry's PANGO lineage.
#' 
#' @param VOCVOI: data frame, group name, designation code and color
#' @param meta:  data frame, metadata including lineages
#' @return character vector of PANGO group assignments, to the smallest group
create.pango.group <-  function(VOCVOI, meta) {
  # a group is defined by the root lineage, e.g., BQ*
  lineage.groups <- lapply(VOCVOI$pangodesignation, function(pg) {
    getStrictoSubLineages(pg, meta)
    })
  names(lineage.groups) <- VOCVOI$name
  rest= unique(meta$lineage)
  rest <- rest[! rest %in% unlist(lineage.groups)]
  lineage.groups[["Recombinants"]]  <- rest[grepl("^X", rest)]
  # re-order in decreasing order to handle duplicates, since a derived 
  # group will necessarily have fewer members
  # e.g., BQ.1 is in both Omicron BA.5 and Omicron BQ, but the latter is a
  # smaller group  
  n.derived <- sapply(lineage.groups, length)
  lineage.groups <- lineage.groups[order(n.derived, decreasing=TRUE)]
  print(names(lineage.groups))
  print(n.derived)
  col <- rep("other", nrow(meta))  # prepare output vector
  for (i in 1:length(lineage.groups)) {
    # this will overwrite PANGO groups with derived group labels
    idx <- which(is.element(meta$lineage, lineage.groups[[i]]))
    col[idx] <- names(lineage.groups)[i]
  }

  return(col)
}

