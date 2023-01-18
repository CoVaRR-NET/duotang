require(lubridate)



#' generate stacked barplot of a subset of lineages
#' @param region:  char, can be used to select samples for a specific province
#' @param sublineage:  char, vector of lineage names for subsetting
#' @param scaled:  bool, display absolute or relative frequencies per week
#' @param mindate:  Date, exclude counts preceding this date
plot.subvariants <- function(region='Canada', sublineage, 
                             scaled=FALSE, mindate=NA, maxdate=NA) {
  if(is.na(maxdate)){
    maxdate=max(metaV$sample_collection_date)
  }
  if(is.na(mindate)){
    mindate=as.Date("2021-01-01")
  }
  
  varmeta1 <- meta %>%  filter(lineage %in% sublineage, sample_collection_date>mindate, sample_collection_date<=maxdate, province %in% get.province.list(region))
  varmeta1$pango_group <- varmeta1$lineage
  lineagecount=varmeta1 %>% group_by(lineage) %>% count()
  
  varmetaV1 <- metaV %>%  filter(lineage %in% sublineage, sample_collection_date>mindate, sample_collection_date<=maxdate, province %in% get.province.list(region))
  varmetaV1$pango_group <- varmetaV1$lineage
  lineagecountV=varmetaV1 %>% group_by(lineage) %>% count()
  max=15
  if(nrow(lineagecountV)>max)
  { 
    lineagecount=as_data_frame(lineagecount)
    rarelineages <- lineagecount %>% slice_min(n,n=nrow(lineagecount)-max) #filter(n<0.01*nrow(varmetaV1))
    rarelineages_names=sapply(list(paste(rarelineages$lineage,"(",rarelineages$n,")",sep="")), paste, collapse = ", ")
    varmetaV1$pango_group<-replace(varmetaV1$pango_group, varmetaV1$pango_group  %in% rarelineages$lineage, "other lineages")
    varmeta1$pango_group<-replace(varmeta1$pango_group, varmeta1$pango_group  %in% rarelineages$lineage, "other lineages")
  }
  else{rarelineages_names=""}
  
  varmetaV1$pango_group <- as.factor(varmetaV1$pango_group)
  
  if(nrow(lineagecountV)<5){
    varmeta1$pango_group <- factor(varmeta1$pango_group)
    set.seed(320)
    pal <- sample(rainbow(length(levels(varmeta1$pango_group))))
    names(pal) <- levels(varmeta1$pango_group)
    pal["other lineages"] <- 'grey'  # named character vector
    pal <- pal[match(levels(varmeta1$pango_group), names(pal))]
  }else{
    varmeta1$pango_group <- factor(varmeta1$pango_group, levels=levels(varmetaV1$pango_group))
    set.seed(320)
    pal <- sample(rainbow(length(levels(varmetaV1$pango_group))))
    names(pal) <- levels(varmetaV1$pango_group)
    pal["other lineages"] <- 'grey'  # named character vector
    pal <- pal[match(levels(varmetaV1$pango_group), names(pal))]
  }
  
  if(nrow(varmeta1)>10){
    varmeta1$week <- cut(varmeta1$sample_collection_date, 'week')
    tab <- table(varmeta1$pango_group, varmeta1$week)
    max.count <- max(apply(tab, 2, sum))
  }
  if(nrow(varmetaV1)>10){
    varmetaV1$week <- cut(varmetaV1$sample_collection_date, 'week')
    tabV <- table(varmetaV1$pango_group, varmetaV1$week)
    max.count=max(max.count,max(apply(tabV, 2, sum)))
  }
  if(nrow(varmetaV1)>10){
    if (scaled) {
        par(mar=c(5,5,1,5))
        tab2 <- apply(tabV, 2, function(x) x/sum(x))
        barplot(tab2, col=pal, 
                border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
                ylab="Sequenced cases per week (fraction)",main = "VirusSeq") -> mp
        legend(x=max(mp)+1, y=1, legend=rev(levels(varmetaV1$pango_group)), 
               bty='n', xpd=NA, cex=0.7, fill=rev(pal), 
               x.intersp=0.5, y.intersp=1, border=NA)
    }else {
      par(mar=c(5,5,3,5), adj=0)
      epi <- epidataCANall[epidataCANall$prname==region, ]
      cases.wk <- epi$numtotal_last7
      
      # match case counts to variant freq data and rescale as 2nd axis
      idx <- match(floor_date(epi$date, "weeks", week_start=1),
                   floor_date(as.Date(levels(varmetaV1$week)), "weeks", week_start=1))
      y <- cases.wk[!is.na(idx)]
      y[is.na(y)] <- 0
      lab.y <- pretty(y)  # for drawing axis
      y2 <- (y-min(y)) / (max(y)-min(y)) * max.count  # scale to variant counts
      at.y <- (lab.y-min(lab.y)) / (max(y)-min(y)) * max.count
      barplot(tabV, col=pal, 
              border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
              ylab="Sequenced cases per week",main = "VirusSeq",ylim=range(pretty(c(0, max.count)))) -> mp
      lines(mp, y2, xpd=NA, col=rgb(0,0,0,0.5), lwd=3)
      axis(side=4, at=at.y, labels=format(lab.y, format = 'd'), hadj=0,
           las=1, cex.axis=0.7, col='grey50', col.ticks='grey50',
           col.axis='grey50')
    }}
  if(nrow(varmeta1)>10){
    if (scaled) {
      par(mar=c(5,5,1,5))
      tab2 <- apply(tab, 2, function(x) x/sum(x))
      barplot(tab2, col=pal, 
              border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
              ylab="Sequenced cases per week (fraction)",main = "GISAID") -> mp
      legend(x=max(mp)+1, y=1, legend=rev(levels(varmeta1$pango_group)), 
             bty='n', xpd=NA, cex=0.7, fill=rev(pal), 
             x.intersp=0.5, y.intersp=1, border=NA)
    }else{
      par(mar=c(5,5,3,5), adj=0)
      epi <- epidataCANall[epidataCANall$prname==region, ]
      cases.wk <- epi$numtotal_last7
      
      # match case counts to variant freq data and rescale as 2nd axis
      idx <- match(floor_date(epi$date, "weeks", week_start=1),
                   floor_date(as.Date(levels(varmeta1$week)), "weeks", week_start=1))
      y <- cases.wk[!is.na(idx)]
      y[is.na(y)] <- 0
      lab.y <- pretty(y)  # for drawing axis
      y2 <- (y-min(y)) / (max(y)-min(y)) * max.count  # scale to variant counts
      at.y <- (lab.y-min(lab.y)) / (max(y)-min(y)) * max.count
      barplot(tab, col=pal, 
              border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
              ylab="Sequenced cases per week",main = "GISAID",ylim=range(pretty(c(0, max.count)))) -> mp
      lines(mp, y2, xpd=NA, col=rgb(0,0,0,0.5), lwd=3)
      axis(side=4, at=at.y, labels=format(lab.y, format = 'd'), hadj=0,
           las=1, cex.axis=0.7, col='grey50', col.ticks='grey50',
           col.axis='grey50')
  }}
  return(unique(varmetaV1$lineage))
}


