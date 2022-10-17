plot_growing_lineage <- function(r){
  d = data.frame(lineage = character(),
                 sel_coeff = numeric(),
                 low_CI = numeric(),
                 high_CI = numeric(),
                 size = numeric())
  
  for(i in 1:length(r)){
    sel_coeff=(r[[i]]$fit)$fit[["s1"]]
    low_CI = (r[[i]]$fit)$confint["s1", "2.5 %"]
    high_CI = (r[[i]]$fit)$confint["s1", "97.5 %"]
    if(sel_coeff>0){
      s=sum(r[[i]]$est$toplot$n2)
      d[nrow(d)+1, ] <-c(lineage = r[[i]]$mut,
                         sel_coeff= round(sel_coeff*100000)/1000,
                         low_CI = round(low_CI*100000)/1000,
                         high_CI =round(high_CI*100000)/1000,
                         size = s)
    }
  }
  d$sel_coeff=as.numeric(d$sel_coeff)
  d$low_CI=as.numeric(d$low_CI)
  d$high_CI=as.numeric(d$high_CI)
  d$size=as.numeric(d$size)
  
  bins=c(0,20,50,100,200,500,10000000)
  labels <- gsub("(?<!^)(\\d{3})$", ",\\1", bins, perl=T)
  rangelabels <- paste(head(labels,-1), tail(labels,-1), sep="-")
  rangelabels[length(rangelabels)]="500 and more"
  d$sequence_count=as.factor(cut(d$size,bins,rangelabels,left = FALSE))
  d$lineage = factor(d$lineage, levels=d[order(d$sel_coeff),]$lineage)
  
  p <- ggplot(d, aes(x=lineage, y=sel_coeff,colour=sequence_count))+
  geom_point(size=4)+
  geom_pointrange( aes(ymin=low_CI, ymax=high_CI))+
  geom_hline(yintercept=10, linetype="dashed", color = "grey")+ #dash line at 10% per day to mark doubling in < week
  annotate("rect", xmin = 0, xmax = nrow(d)
           +1, ymin = 0, ymax = 5,
             alpha = .05,fill = "blue")+
  annotate("rect", xmin = 0, xmax = nrow(d)+1, ymin = 5, ymax = 10,
             alpha = .2,fill = "pink")+
  annotate("rect", xmin = 0, xmax = nrow(d)+1, ymin = 10, ymax = max(d$high_CI,11),
             alpha = .2,fill = "orange")+
  scale_y_continuous(breaks=seq((round(min(d$sel_coeff)/5))*5,round(max(d$high_CI,11)/5)*5,5))+
  coord_flip()+ scale_color_brewer(palette = "Green")+
  ggtitle("Recently designated lineages showing most growth")+ labs(x="", y= paste("growth advantage, s, (% per day)\n relative to", namereference, "and 95% CI"))+theme_bw()
  plot(p)
  return(d)
}
