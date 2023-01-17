

get.province.list <- function(region){
  # handle special values for prov
  if (region[1] == "East provinces (NL+NS+NB)") {
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


add.pango.group <-  function(n,p,c) {
  return(rbind(VOCVOI,data.frame(name=n,pangodesignation=p,color=c)))
}
