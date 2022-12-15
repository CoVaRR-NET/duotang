#code used to draw interactive phylogenetic trees by Justin Jia https://github.com/bfjia

DrawTree <- function(tree, metadata, treeType, VOCVOI, fieldnames = c("fasta.header.name", "province", "host.gender", "host.age.bin", "sample.collection.date", 
                                                    "sample.collected.by", "purpose.of.sampling", "purpose.of.sequencing",
                                                    "lineage", "pango.group")){
  suppressWarnings(tt.layout <- tree.layout(tree, type='r'))
  #assign default colour to init color variable in json
  
  tt.layout$nodes$colour <- "#777777"
  tt.layout$edges$colour <- "#777777"
  
  for (field in fieldnames) {
    temp <- rep(NA, nrow(tt.layout$edges))
    temp[tt.layout$edges$isTip] <- as.character(metadata[[field]])
    tt.layout$edges[[field]] <- temp
  }
  
  # append vertical edges
  v.edges <- t(sapply(split(tt.layout$edges, tt.layout$edges$parent), function(e) {
    x <- e[1,]$x0
    c(parent=NA, child=NA, length=NA, isTip=NA, 
      x0=x, x1=x, y0=min(e$y0), y1=max(e$y0),
      colour=e[1,]$colour)
  }))
  edges <- merge(tt.layout$edges, v.edges, all=TRUE)  # tips, internals
  jsonObj <- toJSON(list(nodes=tt.layout$nodes, edges=edges, treetype=treeType, VOCVOI=VOCVOI))
  
  return(jsonObj)
}

reduce.tipnames <- function(tip.label) {
  sapply(tip.label, function(x) {
    tokens <- strsplit(x, "_")[[1]]
    ntok <- length(tokens)
    paste(tokens[1:(ntok-2)], collapse='_')
  })
}