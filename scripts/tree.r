#' Converts a phylogentic tree object into a Json file compatible with the interactive tree visulization js script.
#' Return a Json object.
#' @param tree:  Phylogenetic tree
#' @param metadata: Metadata
#' treeType: The type of tree being constructed.
#' VOCVOI: the VOCVOI colro table.
#' defaultColorField: The default category for the color. DEFAULT="pango_group"
#' fieldnames: List of column names that should be displayed on the mouse hover-over box
DrawTree <- function(tree, metadata, treeType, VOCVOI, defaultColorField = "pango_group", fieldnames = c("fasta.header.name", "province", "host.gender", "host.age.bin", "sample.collection.date", 
                                                    "sample.collected.by", "purpose.of.sampling", "purpose.of.sequencing",
                                                    "lineage", "pango.group")){
  #tree = mltree
  #metadata=metasub1
  #treeType = "mltree"
  #VOCVOI = presetColors
  #fieldnames=fieldnames
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
  
  tt.layout$edges$direction = "X"
  v.edges.t <- as.data.frame(v.edges)
  v.edges.t$direction = "Y"
  
  #lets simply this data
  #isTip, direction, X, Y, Delta, metadata.
  
  edges <- merge(tt.layout$edges, v.edges.t, all=TRUE)  # tips, internals
  edges <- edges %>% mutate(delta = ifelse(direction=="X",as.numeric(x1)-as.numeric(x0), as.numeric(y1)-as.numeric(y0)))
  edges <- edges %>% dplyr::select(-colour, -parent, -child, -length, -x1, -y1)

  jsonObj <- toJSON(list(nodes=NA, edges=edges, treetype=treeType, ntips=nrow(subset(tt.layout$nodes, n.tips == 0)), defaultColorBy=defaultColorField, VOCVOI=VOCVOI))
  
  return(jsonObj)
}


#' remove collection dates to make it easier to link to metadata
#' tips are labelled with [fasta_name]_[lineage]_[coldate]
#' @param tip.label: character vector
#' @return character vector
reduce.tipnames <- function(tip.label) {
  sapply(tip.label, function(x) {
    tokens <- strsplit(x, "_")[[1]]
    ntok <- length(tokens)
    paste(tokens[1:(ntok-2)], collapse='_')
  })
}