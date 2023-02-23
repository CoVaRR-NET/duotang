

get.province.list <- function(region){
  # handle special values for prov
  if (region[1] == "East provinces (NL+NS+NB+PE)") {
    provlist <- c("Nova Scotia", "New Brunswick", "Newfoundland and Labrador", "Prince Edward Island")
  } else if (region[1] == "Canada") {
    provlist <- unique(meta$province)
  } else {
    provlist <- region
  }
  return(provlist)
}

#print only whan no kniting
printest <-function(x){
  if(is.null(knitr::opts_knit$get("out.format"))){
    print(x)
  }
}


# FIXME: this is deprecated now that VOCVOI is loaded from CSV file
add.pango.group <-  function(n,p,c) {
  return(rbind(VOCVOI,data.frame(name=n,pangodesignation=p,color=c)))
}

#' This function generates an empty ggplot object with a text message in the middle.
#' @param message. String. Message to be displayed on the plot.
getEmptyErrorPlotWithMessage <- function(message){
  emptyErrorPlot<- ggplot() + theme_bw() + 
    annotate("text", x=8, y=8, label = message) +
    theme(legend.position=c(0.35, 0.90), legend.title=element_blank(), 
          legend.text=element_text(size=20), 
          legend.background = element_blank(), 
          legend.key=element_blank(),
          legend.spacing.y = unit(0.5, "cm"),
          legend.key.size = unit(2, "cm"),
          axis.title=element_blank(),
          axis.text=element_blank(),
          axis.ticks=element_blank(),
          text = element_text(size = 30)) 
  return (emptyErrorPlot)
}