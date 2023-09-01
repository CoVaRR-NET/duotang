# RTT code contributed by Art Poon

source("scripts/tree.r")
require(MASS)

blobs <- function(x, y, col, cex=1) {
  points(x, y, pch=21, cex=cex)
  points(x, y, bg=col, col=rgb(0,0,0,0), pch=21, cex=cex)
}

dlines <- function(x, y, col) {
  lines(x, y, lwd=2.5)
  lines(x, y, col=col)
}


#' fit.rtt
#' Fit root-to-tip regression to a rooted maximum likelihood tree, in which 
#' branch lengths are measured in units of expected numbers of substitutions 
#' per site.
#' @param path:  path to file containing a Newick tree string
fit.rtt <- function(path) {
  
  rooted <- read.tree(path)
  
  # link to metadata
  rooted$tip.label <- reduce.tipnames(rooted$tip.label)
  
  #scale to number of mutations
  rooted$edge.length <- rooted$edge.length*29903
  
  # extract rows from metadata table that correspond to ttree 
  metadataRTT <- meta[meta$fasta_header_name %in% rooted$tip.label, ]
  index1 <- match(rooted$tip.label, metadataRTT$fasta_header_name)
  if(sum(is.na(index1))!=0){
    print("some samples in the tree do not have sampling dates inthe metadatas")
    return()
  }
  
  # package information for JavaScript
  tips <- data.frame(
    label = rooted$tip.label,
    pango = metadataRTT$pango_group[index1],
    div = node.depth.edgelength(rooted)[1:Ntip(rooted)],
    coldate = as.Date(metadataRTT$sample_collection_date[index1])
  )
  rownames(tips) <- NULL
  
  # fit regressions for each PANGO group
  coldate <- as.Date(tips$coldate)
  pg <- tips$pango
  div <- tips$div
  
  fit0 <- rlm(div[pg=='other'] ~ coldate[pg=='other'])
  names(fit0$coefficients) <- c('y', 'x')
  fits <- list(other=fit0)
  for (i in 1:nrow(VOCVOI)) {
    variant <- VOCVOI$name[i]
    if (sum(pg==variant, na.rm=T) < 3) {
      next
    }
    x <- coldate[pg==variant]
    if (all(is.na(x))) next
    y <- div[pg==variant]
    
    suppressWarnings(fit <- rlm(y ~ x))
    fits[[variant]] <- fit
  }
  
  fit.global <- rlm(div ~ coldate)
  names(fit.global$coefficients) <- c('y', 'x')
  
  fits[["global"]] <- fit.global
  
  #fit.VOCVOI <- rlm(div[pg %in% VOCVOI$name] ~ coldate[pg %in% VOCVOI$name])
  
  list(fits=fits, tips=tips)
}

# deprecated?
confint.rlm <- function(object, ...) {
  # https://stackoverflow.com/questions/49156932/getting-confidence-intervals-for-robust-regression-coefficient-massrlm
  object$df.residual <- MASS:::summary.rlm(object)$df[2]
  confint.lm(object, ...)
}

get.ci <- function(fits) {
  ci <- lapply(fits, confint.rlm)
  est <- data.frame(
    n = sapply(fits, function(f) nrow(f$x)),                            
    est = sapply(fits, function(f) f$coef[2]),
    lower.95 = sapply(ci, function(f) f[2,1]),
    upper.95 = sapply(ci, function(f) f[2,2])
  )
  est$Lineage <- row.names(est)
  est
}

