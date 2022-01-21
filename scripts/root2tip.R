args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("\n\nUsage: Rscript root2tip.R [input NWK] (options) > [output NWK]\n",
       "  input NWK:  Newick tree string from ML reconstruction\n",
       "  delimiter:  (optional) char separating fields in tip labels, default '_'\n",
       "  position:  (optional) index of field corresponding to collection date,\n",
       "             use negative values to count from last field, (default -2)\n",
       "  format:  (optional) date format (ISO default yyyy-mm-dd)\n",
       "  output NWK:  written to standard output stream\n\n")
}

delimiter <- '_'
if (length(args) > 1) delimiter <- args[2]
pos <- -2
if (length(args) > 2) pos <- as.integer(args[3])
format <- '%Y-%m-%d'
if (length(args) > 3) format <- args[4]


require(ape)
require(lubridate)

phy <- read.tree(args[1])

get.dates <- function(phy, delimiter='_', pos=-1, format='%Y-%m-%d') {
  dt <- sapply(phy$tip.label, function(x) {
    tokens <- strsplit(x, delimiter)[[1]]
    if (pos < 0) { return(tokens[length(tokens)+pos+1]) }
    else { return(tokens[pos]) }
  })
  as.Date(dt, format=format)
}

tip.dates <- get.dates(phy, delimiter=delimiter, pos=pos, format=format)
rooted <- rtt(phy, as.integer(tip.dates), objective="rms")
cat(write.tree(rooted))



