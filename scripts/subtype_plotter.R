require(lubridate)

#' DEPRECATED. Use plot.subvariants.ggplot() to generate stacked barplot of a subset of lineages
#' @param region:  char, can be used to select samples for a specific province
#' @param sublineage:  char, vector of lineage names for subsetting
#' @param scaled:  bool, display absolute or relative frequencies per week
#' @param mindate:  Date, exclude counts preceding this date
plot.subvariants <- function(region='Canada', sublineage, 
                             scaled=FALSE, col=NA, mindate=NA, maxdate=NA) {
  #sublineage <- set
  #region = 'Canada'
  #scaled=FALSE
  #col=NA
  #mindate=mindate
  #maxdate=maxdate
  if(is.na(maxdate)){
    maxdate=max(meta$sample_collection_date)
  }
  if(is.na(mindate)){
    mindate=as.Date("2021-01-01")
    
  }
  varmeta1 <- meta %>%  filter(lineage %in% sublineage, sample_collection_date>mindate, sample_collection_date<=maxdate, province %in% get.province.list(region))
  varmeta1$pango_group <- varmeta1$lineage
  
  lineagecount=varmeta1 %>% group_by(lineage) %>% count()
  max=30
  if(nrow(lineagecount)>max)
  { 
    lineagecount=as_data_frame(lineagecount)
    rarelineages <- lineagecount %>% slice_min(n,n=nrow(lineagecount)-max) #filter(n<0.01*nrow(varmeta1))
    rarelineages_names=sapply(list(paste(rarelineages$lineage,"(",rarelineages$n,")",sep="")), paste, collapse = ", ")
    varmeta1$pango_group<-replace(varmeta1$pango_group, varmeta1$pango_group  %in% rarelineages$lineage, "other lineages")
  }
  else{rarelineages_names=""}
  
  varmeta1$pango_group <- as.factor(varmeta1$pango_group)
  
  varmeta1$week <- cut(varmeta1$sample_collection_date, 'week')
  varmeta1 <- varmeta1[as.Date(varmeta1$week) > mindate, ]
  
  if (is.na(col)) {
    set.seed(42069) #setted for 15 colors were close shades are not contiguous
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
    

    barplot(tab, col=pal, 
            border=NA, las=2, cex.names=0.6, cex.axis=0.8, 
            ylab="Sequenced cases per week") -> mp
    
    y <- cases.wk[!is.na(idx)]
    y[is.na(y)] <- 0 #sometimes there is no data for a given week 
    lab.y <- pretty(y)  # for drawing axis
    max.count <- max(apply(tab, 2, sum))
    y2 <- (y-min(y)) / (max(y)-min(y)) * max.count  # scale to variant counts
    at.y <- (lab.y-min(lab.y)) / (max(y)-min(y)) * max.count
    if (length(y2) != length(mp)){
      y2 <- c(y2, rep(0, length(mp)-length(y2)))
    }
    lines(mp, y2, xpd=NA, col=rgb(0,0,0,0.5), lwd=3)
    axis(side=4, at=at.y, labels=format(lab.y, scientific=F), hadj=0,
         las=1, cex.axis=0.7, col='grey50', col.ticks='grey50',
         col.axis='grey50')
  }
  return(rarelineages_names)
}


#' generate stacked barplot of a subset of lineages
#' @param region:  char, can be used to select samples for a specific province
#' @param sublineage:  char, vector of lineage names for subsetting
#' @param scaled:  bool, display absolute or relative frequencies per week
#' @param mindate:  Date, exclude counts preceding this date
plot.subvariants.ggplot <- function(region='Canada', sublineage, 
                             scaled=FALSE, col=NA, mindate=NA, maxdate=NA) {
  #sublineage <- set
  #region = 'Canada'
  #scaled=FALSE
  #col=NA
  #mindate=mindate
  #maxdate=maxdate
  if(is.na(maxdate)){
    maxdate=max(meta$sample_collection_date)
  }
  if(is.na(mindate)){
    mindate=as.Date("2021-01-01")  
  }
  varmeta1 <- meta %>%  filter(lineage %in% sublineage, sample_collection_date>mindate, sample_collection_date<=maxdate, province %in% get.province.list(region))
  varmeta1$pango_group <- varmeta1$lineage
  
  lineagecount=varmeta1 %>% group_by(lineage) %>% count()
  max=50
  if(nrow(lineagecount)>max){ 
    lineagecount=as_data_frame(lineagecount)
    rarelineages <- lineagecount %>% slice_min(n,n=nrow(lineagecount)-max) #filter(n<0.01*nrow(varmeta1))
    rarelineages_names=sapply(list(paste(rarelineages$lineage,"(",rarelineages$n,")",sep="")), paste, collapse = ", ")
    varmeta1$pango_group<-replace(varmeta1$pango_group, varmeta1$pango_group  %in% rarelineages$lineage, "other lineages")
  } else{
    rarelineages_names=""
  }
  varmeta1$pango_group <- as.factor(varmeta1$pango_group)
  varmeta1$week <- cut(varmeta1$sample_collection_date, 'week')
  varmeta1 <- varmeta1[as.Date(varmeta1$week) > mindate, ]
  
  if (is.na(col)) {
    set.seed(25041) #setted for 15 colors were close shades are not contiguous
    col <- sample(rainbow(length(levels(varmeta1$pango_group))))  # default colour palette
  }
  pal <- col
  names(pal) <- levels(varmeta1$pango_group)
  pal["other lineages"] <- '#5A5A5A'  # named character vector
  pal <- pal[match(levels(varmeta1$pango_group), names(pal))]
  
  #bind everything into a table
  tab <- as.data.frame(table(varmeta1$pango_group, as.Date(varmeta1$week)), stringsAsFactors = F) %>% left_join((data.frame(pal) %>% rownames_to_column()), by=c("Var1"="rowname"))
  colnames(tab) <- c("Lineage", "Date", "Frequency", "Color")
  tab$Date <- floor_date(as.Date(tab$Date), "weeks", week_start = 1)
  #total case count data
  epi <- epidataCANall[epidataCANall$prname==region, ] %>% dplyr::select(date, numtotal_last7) %>% mutate(date=floor_date(as.Date(date), "weeks", week_start = 1))
  tab <- tab %>% left_join(epi, by=c("Date"="date")) 
  #coefficient used to scale the total case so that it fits into the same graph. 
  coeff <- max(tab$numtotal_last7) / (tab %>% group_by(Date) %>% summarise(sum=sum(Frequency)) %>% dplyr::select(sum) %>% max() %>% as.numeric)
  tab <- tab %>% mutate(numtotal_last7 = round(numtotal_last7/coeff,0)) 
  totalCaseColName <- paste0("TotalCases(x",round(coeff,0),")")
  colnames(tab) <- c("Lineage", "Date", "Frequency", "Color", totalCaseColName)
  #secondary y axis scaling coefficient
  coeff <- max(tab$TotalCases) / (tab %>% group_by(Date) %>% summarise(sum=sum(Frequency)) %>% dplyr::select(sum) %>% max() %>% as.numeric)
  tab <- tab %>% left_join((tab %>% group_by(Date) %>% summarize(total = sum(Frequency))), by="Date") %>%  mutate(`% Frequency` = paste0(round((100* Frequency/ total),0),"%"))
  #view(tab)
  
  #sort the legend by sum of total value in desc order
  Legend_Order <- tab %>% group_by(Lineage) %>% summarise(n=sum(Frequency)) %>% arrange(desc(n)) %>% dplyr::select(Lineage) %>% unlist() %>% as.vector()
  #move the other lineages to the bottom if it exists
  if ('other lineages' %in% Legend_Order)
  {
    Legend_Order <- c(Legend_Order[!(Legend_Order %in% c("other lineages"))],"other lineages")
  }
  
  tab$Lineage <- factor(tab$Lineage, levels=Legend_Order)
  
  cols <- setNames(tab$Color, tab$Lineage)
  cols <- cols[intersect(names(cols),  tab$Lineage)]
  cols <- cols[order(tab$Lineage)]
  cols <- cols[!is.na(cols)]
  
  options(scipen=1000000)

absolute<- ggplot() + 
    geom_bar(data=tab, mapping = aes(x = Date, y=Frequency,  fill = Lineage), position="stack", stat="identity") + 
    scale_fill_manual(name = "Lineages", values = cols) +
    geom_line(data=tab, mapping=aes(x=Date, y=.data[[totalCaseColName]]), color="grey") + 
    scale_x_date(date_breaks = "1 month", label=scales::date_format("%b %Y"), limits = c(min(tab$Date), max = max(tab$Date)))+
    scale_y_continuous(name = "Sequenced cases per week", sec.axis = sec_axis(~., name="Total cases per week", breaks = scales::pretty_breaks(n=6))) +
    #ylab("Sequences cases per week \n(fraction)") +
    theme_bw() +
    labs(caption = paste0("Last day of data is ", max(tab$Date))) +
    theme(legend.text=element_text(size=10), text = element_text(size = 10),axis.text.x = element_text(angle = 90)) 
  
  relative<- ggplot(tab, aes(x=Date, y=Frequency, fill=Lineage)) + 
    geom_bar(position="fill", stat="identity") + 
    scale_fill_manual(name = "Lineages", values = cols) +
    scale_x_date(date_breaks = "1 month", label=scales::date_format("%b %Y"), limits = c(min(tab$Date), max = max(tab$Date)))+
    ylab("Sequences cases per week \n(fraction)") +
    theme_bw() +
    labs(caption = paste0("Last day of data is ", max(tab$Date))) +
    theme(legend.text=element_text(size=10), text = element_text(size = 10),axis.text.x = element_text(angle = 90)) 
  
  return(list("absolute"=absolute, "relative"=relative, "data"=tab))
}

