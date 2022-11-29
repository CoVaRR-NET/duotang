

#print only whan no kniting
printest <-function(x){
  if(is.null(knitr::opts_knit$get("out.format"))){
    print(x)
  }
}


add.pango.group <-  function(n,p,c) {
  return(rbind(VOCVOI,data.frame(name=n,pangodesignation=p,color=c)))
}
