plot_growing_lineage <- function(r, makeplot=TRUE, coefficientTable="", mutantNamesToHighlight = ""){
  # r = paramselected[1:n]
  # coefficientTable = coefficientTable
  # mutantNamesToHighlight = mutantToHighlight
  # makeplot=T
  # # 
  d = data.frame(lineage = character(),
                 sel_coeff = numeric(),
                 low_CI = numeric(),
                 high_CI = numeric(),
                 size = numeric(),
                 region = character())
  
  for(i in 1:length(r)){
    sel_coeff=(r[[i]]$fit)$fit[["s1"]]
    low_CI = (r[[i]]$fit)$confint["s1", "2.5 %"]
    high_CI = (r[[i]]$fit)$confint["s1", "97.5 %"]
    if(sel_coeff>0){
      s=sum(r[[i]]$toplot$n2)
      d[nrow(d)+1, ] <-c(lineage = r[[i]]$mut[1],
                         sel_coeff= round(sel_coeff*100000000)/1000000,
                         low_CI = round(low_CI*100000)/1000,
                         high_CI =round(high_CI*100000)/1000,
                         size = s,
                         region = r[[i]]$region)
    }
  }
  d$sel_coeff=as.numeric(d$sel_coeff)
  d$low_CI=as.numeric(d$low_CI)
  d$low_CI[d$low_CI < 0] <- 0
  d$high_CI=as.numeric(d$high_CI)
  d$size=as.numeric(d$size)
  
  d <- d%>%unique()

  #test.l <- getStrictoSubLineages(test, meta)[1]
  #view(d)
  d$lineage <- sapply(d$lineage, function(x){
    l <- getStrictoSubLineages(x, meta)[1]
    l <- as.character(l)
    return(l)
  })

  if (class(coefficientTable) == "data.frame" ){
    if (unique(d$region) == "Canada"){
      #generate the circle with borders if in more than 1 provinc for canada only plot
      regionPresenceTable <- coefficientTable %>% dplyr::select(lineage, region) %>% filter (region != "Canada") %>% unique() %>% group_by(lineage) %>% summarise(NumRegions=n()) 
     # view(regionPresenceTable)
      regionPresenceTable$lineage <- as.character(regionPresenceTable$lineage)
      d <- d %>% left_join(regionPresenceTable, by="lineage") %>% 
        mutate (MultiRegion = ifelse(NumRegions > 1, 1, 0)) %>% dplyr::select(-NumRegions) %>% mutate(MultiRegion = replace_na(MultiRegion, 0))
    }
  }
  
  if (length(mutantNamesToHighlight) >= 1){
    mutantNamesToHighlight <- c(gsub("\\*", "", mutantNamesToHighlight), mutantNamesToHighlight)
    d <- d %>% mutate(Highlight = ifelse(lineage %in% mutantNamesToHighlight, 1, 0))
  }
  
  d <- d %>% mutate (lineType = ifelse(is.nan(low_CI), "solid", "dashed")) %>% mutate(low_CI = ifelse(is.nan(low_CI), sel_coeff * 0.9, low_CI)) %>% mutate(high_CI = ifelse(is.nan(high_CI), sel_coeff * 1.1, high_CI))
  
  if(makeplot){
    bins=c(0,20,40,80,100,200,500,10000000)
    labelsstart <- head(gsub("(?<!^)(\\d{3})$", ",\\1", bins+1, perl=T),-1)
    labelsend <- tail(gsub("(?<!^)(\\d{3})$", ",\\1", bins, perl=T),-1)
    labelsend[[length(labelsend)]]=""
    rangelabels <- paste(labelsstart, labelsend, sep="-")
    d$`Number of Sequences`=as.factor(cut(d$size,bins,rangelabels,left = FALSE))
    couleur=rev(hcl.colors(length(levels(d$`Number of Sequences`)), "Red-Blue"))
    names(couleur)=levels(d$`Number of Sequences`)
    colScale=scale_colour_manual(name="Number of Sequences",values=couleur)
    d$lineage = factor(d$lineage, levels=d[order(d$sel_coeff),]$lineage)
    
    maxdate=max((meta %>%  filter(province %in% get.province.list(r[[1]]$region)))$sample_collection_date, na.rm=T)
    title=paste("Most recent sequence date:",format(maxdate, "%B %d, %Y"))
    
    if (class(coefficientTable) == "data.frame" ){
      if (unique(d$region) == "Canada")
      {
        p <- ggplot(d, aes(x=lineage, y=sel_coeff,colour=`Number of Sequences`, stroke=MultiRegion)) +
          geom_point(size = 5, shape=21)
      } else{
      p <- ggplot(d, aes(x=lineage, y=sel_coeff,colour=`Number of Sequences`))+
        geom_point(size = 5)
      }
    }
    axisMax <- ifelse(is.finite(max(round((d$high_CI + 2.5)/ 5.0) * 5.0)), max(round((d$high_CI + 2.5)/ 5.0) * 5.0),max(max(round((d$sel_coeff + 2.5)/ 5.0) * 5.0)) )
    #annotate lines and CIs
    p <- p +
    geom_pointrange( aes(ymin=low_CI, ymax=high_CI, linetype = lineType), show.legend = F)+
    geom_hline(yintercept=10, linetype="dashed", color = "grey")+ #dash line at 10% per day to mark doubling in < week
    scale_y_continuous(breaks=seq(0, axisMax,5))+
    coord_flip()+ colScale
    
    if (length(which(d$Highlight == 1)) != 0){
      matching_rows <- length(d$Highlight) - which(d$Highlight == 1) + 1
      p <- p + geom_rect(aes(ymin = -Inf, ymax = Inf, xmin = matching_rows - 0.5, xmax = matching_rows + 0.5), 
                         fill = "lightblue", alpha = 0.02, color = NA) 
    }

    
    #draw in the theme
    p<- p + theme_bw()+
    theme(plot.caption.position = "plot", plot.caption = element_text(hjust=0)) +
    ggtitle(title)+ labs(x="", y= paste("growth advantage (s% per day)\nrelative to ", individualSelectionPlotReference, " with 95% CI bars"))+
      labs(caption = "*Circled dots indicate lineages with a positive selection coefficient in multiple provinces\n*Gray shading indicates the most prevalent strain in the last two weeks\n*Dashed line indicates CI could not be estimated, likely due to low case counts.") 
    #plot(p)
    p
    return(p)
  }
  else{
    return(d)
  }
}
