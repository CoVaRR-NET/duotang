plot_growing_lineage <- function(r, makeplot=TRUE, coefficientTable=""){
  #r = paramselected[1:25]
 # coefficientTable = coefficientTable
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
#iew(d)
  if(makeplot){
    bins=c(0,20,40,80,100,200,500,10000000)
    labelsstart <- head(gsub("(?<!^)(\\d{3})$", ",\\1", bins+1, perl=T),-1)
    labelsend <- tail(gsub("(?<!^)(\\d{3})$", ",\\1", bins, perl=T),-1)
    labelsend[[length(labelsend)]]=""
    rangelabels <- paste(labelsstart, labelsend, sep="-")
    d$sequence_count=as.factor(cut(d$size,bins,rangelabels,left = FALSE))
    couleur=rev(hcl.colors(length(levels(d$sequence_count)), "Red-Blue"))
    names(couleur)=levels(d$sequence_count)
    colScale=scale_colour_manual(name="sequence_count",values=couleur)
    d$lineage = factor(d$lineage, levels=d[order(d$sel_coeff),]$lineage)
    maxdate=max((meta %>%  filter(province %in% get.province.list(r[[1]]$region)))$sample_collection_date)
    title=paste("Most recent sequence date:",format(maxdate, "%B %d, %Y"))
    
    if (class(coefficientTable) == "data.frame" ){
      if (unique(d$region) == "Canada")
      {
        p <- ggplot(d, aes(x=lineage, y=sel_coeff,colour=sequence_count, stroke=MultiRegion)) +
          geom_point(size = 5, shape=21)
      } else{
      p <- ggplot(d, aes(x=lineage, y=sel_coeff,colour=sequence_count))+
        geom_point(size = 5)
      }
    }
    
    axisMax <- ifelse(is.finite(max(round((d$high_CI + 2.5)/ 5.0) * 5.0)), max(round((d$high_CI + 2.5)/ 5.0) * 5.0),max(max(round((d$sel_coeff + 2.5)/ 5.0) * 5.0)) )
    
    p <- p +
    geom_pointrange( aes(ymin=low_CI, ymax=high_CI))+
    geom_hline(yintercept=10, linetype="dashed", color = "grey")+ #dash line at 10% per day to mark doubling in < week
    scale_y_continuous(breaks=seq(0, axisMax,5))+
    coord_flip()+ colScale+
      theme_bw()+
     
    theme(plot.caption.position = "plot", plot.caption = element_text(hjust=0)) +
      
    ggtitle(title)+ labs(x="", y= paste("growth advantage (s% per day)\nrelative to ", individualSelectionPlotReference, " with 95% CI bars"))+
      labs(caption = "*Circled dots indicate lineages with a positive selection coefficient in multiple provinces") 
    #plot(p)
   # p
    return(p)
  }
  else{
    return(d)
  }
}
