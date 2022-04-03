args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("\n\nUsage: Rscript filter-rtt.R [input NWK] [output NWK] [output CSV] (options)\n",
       "  input NWK:  Newick tree string from ML reconstruction\n",
       "  output NWK:  file to write tree with outlier tips removed\n",
       "  output CSV:  file to write tip names and dates for TimeTree\n",
       "  delimiter:  (optional) char separating fields in tip labels, default '_'\n",
       "  position:  (optional) index of field corresponding to collection date,\n",
       "             use negative values to count from last field, (default -1)\n",
       "  format:  (optional) date format (ISO default yyyy-mm-dd)\n\n")
}

# set default options
delimiter <- '_'
if (length(args) > 3) delimiter <- args[4]
pos <- -1
if (length(args) > 4) pos <- as.integer(args[5])
format <- '%Y-%m-%d'
if (length(args) > 5) format <- args[6]


require(ape)
rtt <- read.tree(args[1])

get.dates <- function(phy, delimiter='_', pos=-1, format='%Y-%m-%d') {
  dt <- sapply(phy$tip.label, function(x) {
    tokens <- strsplit(x, delimiter)[[1]]
    if (pos < 0) { return(tokens[length(tokens)+pos+1]) }
    else { return(tokens[pos]) }
  })
  as.Date(dt, format=format)
}

tip.dates <- get.dates(rtt, delimiter, pos, format)
div <- node.depth.edgelength(rtt)[1:Ntip(rtt)]
fit <- lm(div~tip.dates)
out <- summary(fit)
stderr <- out$coefficients[1,2]

# visualization
#par(mar=c(5,5,1,1))
plot(tip.dates, div, pch=19, cex=0.5, col=rgb(0.5,0,0,0.2), bty='n')
#abline(fit, lwd=2)
#plot(residuals(fit), cex=0.5)
#abline(a=fit$coef[1]+3*stderr, b=fit$coef[2], lty=2)
#abline(a=fit$coef[1]-3*stderr, b=fit$coef[2], lty=2)

outliers <- which(abs(residuals(fit)) > 3*stderr)
#plot(tip.dates, residuals(fit))
#points(tip.dates[outliers], residuals(fit)[outliers], col='red')

pruned <- drop.tip(rtt, tip=rtt$tip.label[outliers])
write.tree(pruned, file=args[2])

dates <- data.frame(name=pruned$tip.label, date=tip.dates[-outliers])
write.table(dates, sep='\t', file=args[3], row.names=F, quote=F)
