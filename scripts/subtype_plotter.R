require(lubridate)



#' generate stacked barplot of a subset of lineages
#' @param region:  char, can be used to select samples for a specific province
#' @param sublineage:  char, vector of lineage names for subsetting
#' @param scaled:  bool, display absolute or relative frequencies per week
#' @param mindate:  Date, exclude counts preceding this date
plot.subvariants <- function(region='Canada', sublineage=c(name1), 
                             scaled=FALSE, col=NA, mindate=as.Date('2021-11-01'), maxdate=NA) {
  if(is.na(maxdate)){
    varmeta1 <- meta %>%  filter(lineage %in% sublineage, sample_collection_date>mindate, province %in% get.province.list(region))
  }
  else{
    varmeta1 <- meta %>%  filter(lineage %in% sublineage, sample_collection_date>mindate, sample_collection_date<=maxdate, province %in% get.province.list(region))
  }
  
  varmeta1$pango_group <- varmeta1$lineage
  
  lineagecount=varmeta1 %>% group_by(lineage) %>% count()
  max=15
  if(nrow(lineagecount)>max)
  { 
    lineagecount=as_data_frame(lineagecount)
    rarelineages <- lineagecount %>% slice_min(n,n=nrow(lineagecount)-max) #filter(n<0.01*nrow(varmeta1))
    rarelineages_names=sapply(list(paste(rarelineages$lineage,"(",rarelineages$n,")",sep="")), paste, collapse = ", ")
    varmeta1$pango_group<-replace(varmeta1$pango_group, varmeta1$pango_group  %in% rarelineages$lineage, "other lineages")
  }
  else{rarelineages_names=""}
  
  varmeta1$pango_group <- as.factor(varmeta1$pango_group)
  
  #print(varmeta1$sample_collection_date)
  
  varmeta1$week <- cut(varmeta1$sample_collection_date, 'week')
  varmeta1 <- varmeta1[as.Date(varmeta1$week) > mindate, ]
  varmeta1$week <- as.factor(as.character(varmeta1$week))
  
  if (is.na(col)) {
    set.seed(320)
    col <- sample(rainbow(length(levels(varmeta1$pango_group))))  # default colour palette
  }
  pal <- col
  names(pal) <- levels(varmeta1$pango_group)
  pal["other lineages"] <- 'grey'  # named character vector
  pal <- pal[match(levels(varmeta1$pango_group), names(pal))]
  tab <- table(varmeta1$pango_group, varmeta1$week)
  
  if (scaled) {
    par(mar=c(5,5,1,5))
    tab2 <- apply(tab, 2, function(x) x/sum(x))
    barplot(tab2, col=pal, 
            border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
            ylab="Sequenced cases per week (fraction)") -> mp
    legend(x=max(mp)+1, y=1, legend=rev(levels(varmeta1$pango_group)), 
           bty='n', xpd=NA, cex=0.7, fill=rev(pal), 
           x.intersp=0.5, y.intersp=1, border=NA)
  } 
  else {
    par(mar=c(5,5,3,5), adj=0)
    epi <- epidataCANall[epidataCANall$prname==region, ]
    #epi$week <- cut(as.Date(epi$date), 'week')
    #cases.wk <- sapply(split(epi$numtoday, epi$week), sum)
    cases.wk <- epi$numtotal_last7
    
    # match case counts to variant freq data and rescale as 2nd axis
    idx <- match(floor_date(epi$date, "weeks", week_start=1), 
                 floor_date(as.Date(levels(varmeta1$week)), "weeks", week_start=1))
    y <- cases.wk[!is.na(idx)]
    lab.y <- pretty(y)  # for drawing axis
    max.count <- max(apply(tab, 2, sum))
    y2 <- y / (max(y)-min(y)) * max.count  # scale to variant counts
    at.y <- lab.y / (max(y)-min(y)) * max.count
    
    barplot(tab, col=pal, 
            border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
            ylab="Sequenced cases per week") -> mp
    lines(mp, y2, xpd=NA, col=rgb(0,0,0,0.5), lwd=3)
    axis(side=4, at=at.y, labels=format(lab.y, scientific=F), hadj=0,
         las=1, cex.axis=0.7, col='grey50', col.ticks='grey50',
         col.axis='grey50')
  }
  return(rarelineages_names)
}


