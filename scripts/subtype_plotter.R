#' generate stacked barplot of a subset of lineages
#' @param region:  char, can be used to select samples for a specific province
#' @param sublineage:  char, vector of lineage names for subsetting
#' @param scaled:  bool, display absolute or relative frequencies per week
plot.subvariants <- function(region='Canada', sublineage=c(name1), 
                             scaled=FALSE, col=NA) {
  if (is.na(col)) {
    col <- rainbow(length(sublineage))  # default colour palette
  }
  VOCVOI1 <- data.frame(
    name=sublineage,
    pattern=sublineage,
    color=col
  )
  varmeta1 <- meta %>% filter(lineage %in% sublineage)
  #length(varmeta1$lineage)
  
  variants1 <- sapply(VOCVOI1$pattern, function(p) 
    grepl(p, varmeta1$lineage, perl=T))
  varmeta1$pango.group <- varmeta1$lineage
  varmeta1$pango.group <- as.factor(varmeta1$pango.group)
  
  varmeta1$week <- cut(varmeta1$sample.collection.date, 'week')
  varmeta1 <- varmeta1[as.Date(varmeta1$week) > as.Date('2021-11-30'), ]
  varmeta1$week <- as.factor(as.character(varmeta1$week))
  
  pal <- VOCVOI1$color
  names(pal) <- VOCVOI1$name
  pal["other"] <- 'grey'  # named character vector
  
  if (region=='Canada') {
    tab <- table(varmeta1$pango.group, varmeta1$week)  
  } else {
    varmeta2 <- varmeta1[varmeta1$geo_loc_name..state.province.territory.==region, ]
    tab <- table(varmeta2$pango.group, varmeta2$week)  
  }
  # reorder colour palette
  pal2 <- pal[match(levels(varmeta1$pango.group), names(pal))]
  
  if (scaled) {
    par(mar=c(5,5,1,5))
    tab2 <- apply(tab, 2, function(x) x/sum(x))
    pal2 <- pal[match(levels(varmeta1$pango.group), names(pal))]
    barplot(tab2, col=pal2, 
            border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
            ylab="Sequenced cases per week (fraction)") -> mp
    legend(x=max(mp)+1, y=1, legend=rev(levels(varmeta1$pango.group)), 
           bty='n', xpd=NA, cex=0.7, fill=rev(pal2), 
           x.intersp=0.5, y.intersp=1, border=NA)
  } 
  else {
    par(mar=c(5,5,3,5), adj=0)
    epi <- epidataCANall[epidataCANall$prname==region, ]
    epi$week <- cut(as.Date(epi$date), 'week')
    cases.wk <- sapply(split(epi$numtoday, epi$week), sum)
    
    # match case counts to variant freq data and rescale as 2nd axis
    idx <- match(names(cases.wk), levels(varmeta1$week))
    y <- cases.wk[!is.na(idx)]
    lab.y <- pretty(y)  # for drawing axis
    max.count <- max(apply(tab, 2, sum))
    y2 <- y / (max(y)-min(y)) * max.count  # scale to variant counts
    at.y <- lab.y / (max(y)-min(y)) * max.count
    
    barplot(tab, col=pal2, 
            border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
            ylab="Sequenced cases per week") -> mp
    lines(mp, y2, xpd=NA, col=rgb(0,0,0,0.5), lwd=3)
    axis(side=4, at=at.y, labels=format(lab.y, scientific=F), hadj=0,
         las=1, cex.axis=0.7, col='grey50', col.ticks='grey50',
         col.axis='grey50')
  }
}
