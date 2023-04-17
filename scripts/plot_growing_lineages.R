plot_growing_lineage <- function(r, makeplot=TRUE){
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
    p <- ggplot(d, aes(x=lineage, y=sel_coeff,colour=sequence_count))+
    geom_point(size=5)+
    geom_pointrange( aes(ymin=low_CI, ymax=high_CI))+
    geom_hline(yintercept=10, linetype="dashed", color = "grey")+ #dash line at 10% per day to mark doubling in < week

    scale_y_continuous(breaks=seq(max((round(min(d$sel_coeff)/5))*5,-5),min(round(max(d$high_CI,11,na.rm = TRUE)/5)*5,15),5))+
    coord_flip()+ colScale+
    ggtitle(title)+ labs(x="", y= paste("growth advantage (s% per day)\nrelative to ", individualSelectionPlotReference, " with 95% CI bars"))+theme_bw()
    #plot(p)
    return(p)
  }
  else{
    return(d)
  }
}
