# RTT code contributed by Art Poon

blobs <- function(x, y, col, cex=1) {
  points(x, y, pch=21, cex=cex)
  points(x, y, bg=col, col=rgb(0,0,0,0), pch=21, cex=cex)
}

dlines <- function(x, y, col) {
  lines(x, y, lwd=2.5)
  lines(x, y, col=col)
}

fit.rtt <- function(path, plot=FALSE) {
  rooted <- read.tree(path)
  rooted$tip.label <- get.tipnames(rooted$tip.label)
  metadataRTT <- meta[meta$fasta.header.name %in% rooted$tip.label, ]
  
  index1 <- match(rooted$tip.label, metadataRTT$fasta.header.name)
  date <- metadataRTT$sample.collection.date[index1]
  pg <- metadataRTT$pango.group[index1]
  date <- as.Date(date)
  # total branch length from root to each tip
  div <- node.depth.edgelength(rooted)[1:Ntip(rooted)]
  
  fit0 <- rlm(div[pg=='other'] ~ date[pg=='other'])
  fits <- list(other=fit0)
  
  if (plot) {
    par(mar=c(5,5,0,1))
    plot(date, div, type='n', las=1, cex.axis=0.6, cex.lab=0.7, bty='n',
         xaxt='n', xlab="Sample collection date", ylab="Divergence from root")
    xx <- floor_date(seq(min(date), max(date), length.out=5), unit="months")
    axis(side=1, at=xx, label=format(xx, "%b %Y"), cex.axis=0.6)  
    blobs(date[pg=='other'], div[pg=='other'], col='grey', cex=1)
    abline(fit0, col='gray50')
  }
  
  for (i in 1:nrow(VOCVOI)) {
    variant <- VOCVOI$name[i]
    if (sum(pg==variant) < 3) {
      next
    }
    x <- date[pg==variant]
    if (all(is.na(x))) next
    y <- div[pg==variant]
    
    suppressWarnings(fit <- rlm(y ~ x))
    fits[[variant]] <- fit
    
    if (plot) {
      blobs(x, y, col=VOCVOI$color[i], cex=0.8)
      dlines(fit$x[,2], predict(fit), col=VOCVOI$color[i])  
    }
  }
  
  if (plot) {
    legend(x=min(date), y=max(div), legend=VOCVOI$name, pch=21,
           pt.bg=VOCVOI$color, bty='n', cex=0.8)    
  }
  fits
}

confint.rlm <- function(object, ...) {
  # https://stackoverflow.com/questions/49156932/getting-confidence-intervals-for-robust-regression-coefficient-massrlm
  object$df.residual <- MASS:::summary.rlm(object)$df[2]
  confint.lm(object, ...)
}
get.ci <- function(fits) {
  ci <- lapply(fits, confint.rlm)
  est <- data.frame(
    n = sapply(fits, function(f) nrow(f$x)),                            
    est = 29903*sapply(fits, function(f) f$coef[2]),
    lower.95 = 29903*sapply(ci, function(f) f[2,1]),
    upper.95 = 29903*sapply(ci, function(f) f[2,2])
  )
  est$Lineage <- row.names(est)
  est
}

