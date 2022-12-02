#' Original implementation in Mathematica by Sarah Otto
#' First port into R by Carmen Murall and Sarah Otto
#' Refactored by Art Poon
suppressMessages({
  require(bbmle, quietly=T)
  require(HelpersMG, quietly=T)
  require(dplyr, quietly=T)
  #require(scales, quietly=T)
})


#' from github.com/ArtPoon/ggfree
alpha <- function(col, alpha) {
  sapply(col, function(cl) {
    vals <- col2rgb(cl)  # convert colour to RGB values
    rgb(vals[1], vals[2], vals[3], alpha*255, maxColorValue=255)
  })
}


get.province.list <- function(region){
  # handle special values for prov
  if (region[1] == "East provinces (NL+NS+NB)") {
    provlist <- c("Nova Scotia", "New Brunswick", "Newfoundland and Labrador")
  } else if (region[1] == "Canada") {
    provlist <- unique(meta$province)
  } else {
    provlist <- region
  }
  return(provlist)
}

.make.estimator <- function(region, startdate, reference, mutants) {
  # filter metadata
  mydata <- meta %>% filter(
    lineage %in% c(unlist(reference), unlist(mutants)), 
    province %in% get.province.list(region),
    !is.na(sample_collection_date),
    sample_collection_date >= startdate
  )
  # separate by reference (n1) and mutant lineage(s) (n2)
  mydata$lineage = mydata$lineage %in% reference
  mydata <- mydata %>% group_by(sample_collection_date) %>% dplyr::count(lineage, name = "n")
  mydata$lineage <- lapply(mydata$lineage, function(isref) if(isref){"n1"}else{"n2"} )
  if(length(unique(mydata$lineage)) !=2 ){
    return(NA)
  }
  
  
  widetable = pivot_wider(mydata, names_from = lineage, values_from = n, values_fill = 0 )
  names(widetable)[names(widetable) == "sample_collection_date"] <- "date"
  
  
  alltime=seq.Date(as.Date(startdate), as.Date(max(widetable$date)), "days") 
  missingrows  <- data.frame (date = alltime[!alltime %in% widetable$date])
  
  toplot=rbind(widetable,missingrows)
  
  # convert time to negative integers for fitting model (0 = last date)
  toplot$time <- as.numeric(difftime(toplot$date, max(toplot$date), units='days'))
  toplot <-toplot[order(toplot$time),]
  # Any NA's refer to no variant of that type on a day, set to zero
  toplot[is.na(toplot)] <- 0 
  
  # To aid in the ML search, we rescale time to be centered as close as possible
  # to the midpoint (p=0.5), to make sure that the alleles are segregating at 
  # the reference date.  If we set t=0 when p (e.g., n1/(n1+n2+n3)) is near 0 
  # or 1, then the likelihood surface is very flat.
  v <- apply(toplot[c("n1","n2")], 1, function(ns) { 
    ifelse(sum(ns)>10, prod(ns) / sum(ns)^length(ns), 0) 
    })
  # Once the refdate is chose, it should be set at 0
  refdate <- which.max(smooth.spline(v[!is.na(v)])$y)
  toplot$time <- toplot$time-min(toplot$time)-refdate
  
  toplot$tot <- apply(toplot[which(!is.element(names(toplot), c('time', 'date')))], 1, sum)
  
  return(toplot)
}


.scurves <- function(p, s, ts) {
  # calculate exponential growths (N e^{st}) over time, where N is replaced 
  # by p with some scaling constant we can ignore
  p.vecs <- matrix(NA, nrow=length(ts), ncol=1+length(p))
  p.vecs[,1] <- rep(1-sum(p), length(ts))  # s=0 for reference, exp(0*t) = 1 for all t
  for (j in 1:length(p)) {
    p.vecs[,j+1] <- p[j] * exp(s[j] * ts)
  }
  p.vecs / apply(p.vecs, 1, sum)  # normalize to probabilities
}


#' log-likelihood for multinomial distribution
#' This assumes that repeated observations over time are independent
#' outcomes determined only by the probabilities of every type.
#' @param p:  vector of mutant frequencies at reference time point
#' @param s:  vector of selection coefficients for mutants relative 
#'            to reference (wildtype)
.llfunc <- function(p, s, toplot) {
  # compute the probabilities for the time serie
  ts=toplot[toplot$tot!=0,]$time
  pr.vecs <- .scurves(p, s, ts)
  
  counts=as.matrix(toplot[toplot$tot!=0,c("n1","n2")])
  # calculate log-likelihood (negative sign because optimizer minimizes)
    -sum(counts * log(pr.vecs))
}


# I had to write these wrapper functions because mle2 doesn't like vector 
# parameters >:(
.ll.trinom <- function(p1, p2, s1, s2, toplot) {
  suppressWarnings(
    .llfunc(p=c(p1, p2), s=c(s1, s2), toplot=toplot)
  )
}

.ll.binom <- function(p1, s1, toplot) {
  suppressWarnings(
    .llfunc(p=p1, s=s1, toplot=toplot)
    )
}


#' fit multinomial model to count data by maximum likelihood
#' @param obj:  data frame, time series for reference type
#' @param startpar:  list, initial parameter values
#' @param method:  character, name of method for call to optim(), defaults to 'BFGS'
#' @return  list, fit = object of class 'mle2'
#'                confint = matrix returned from confint
#'                sample = data frame from RandomHessianOrMCMC
.fit.model <- function(toplot, startpar, method="Nelder-Mead") {
  #print(toplot[toplot$n2!=0,])
  tryCatch(
    {
      if (length(startpar$s) == 1) {
        bbml <- mle2(.ll.binom, start=list(p1=startpar$p[1], s1=startpar$s[1]), 
                     data=list(toplot=toplot), method=method, skip.hessian=FALSE)
      }
      else if (length(startpar$s) == 2) {
        bbml <- mle2(.ll.trinom, 
                     start=list(p1=startpar$p[1], p2=startpar$p[2], 
                                s1=startpar$s[1], s2=startpar$s[2]), 
                     data=toplot, method=method)
      }
      else {
        stop("ERROR: function does not currently support more than three types!")
      }
      
      # based on the quadratic approximation at the maximum likelihood estimate
      myconf <- confint(bbml, method="quad")

      # draw random parameters for confidence interval
      bbfit <- bbml@details$par
      bbhessian <- bbml@details$hessian  # matrix of 2nd order partial derivatives
      dimnames(bbhessian) <- list(names(bbfit), names(bbfit))
      
      if (any(is.nan(bbhessian))) {
        df <- NA
      } else {
        # draw random parameter values from Hessian to determine variation in {p, s}
        df <- RandomFromHessianOrMCMC(Hessian=bbhessian, fitted.parameters=bbfit, 
                                      method="Hessian", replicates=1000, silent=T)$random  
      }
      return(list(fit=bbfit, confint=myconf, sample=df, modelerror=FALSE))
    },
    error=function(cond) {
      return(list(fit=NA, confint=NA, sample=NA, modelerror=TRUE))
    })
}


#' Fit selection model and generate a plot
#' @param region:  character, province name(s)
#' @param startdate:  Date, earliest sample collection date - should not be too
#'                    far before both alleles become common, or else rare 
#'                    migration events may skew estimation.
#' @param reference:  character, one or more PANGO lineage names, e.g., 
#'                    c("BA.1", "BA.2"), as a reference set (wildtype)
#' @param mutants:  list, one or more character vectors of PANGO lineage names 
#'                 to estimate selection advantages for.
#' @param startpar:  list, initial parameter values
#' @param col:  char, vector of colour specification strings
#' @param method:  char, pass to optim()
#' @example 
#' region <- "Canada (no AB)"
#' startdate <- as.Date("2021-12-15")
#' reference <- c("BA.1")  # or c("BA.1", "BA.1.1")
#' mutants <- list("BA.1.1", "BA.2")
#' startpar <- list(p=c(0.4, 0.1), s=c(0.05, 0.05))
estimate.selection <- function(region, startdate, reference, mutants, startpar, method='BFGS') {
  toplot <- .make.estimator(region, startdate, reference, mutants)
  if(any(is.na(toplot))){
    return(list(toplot=NA,fit=NA,mut=mutants,ref=reference, region=region))
  }
  fit <- .fit.model(toplot, startpar, method=method)
  return(list(toplot=toplot,fit=fit,mut=mutants,ref=reference, region=region))
}






plot.selection <- function(plotparam, col=c('red', 'blue')) {
  toplot=plotparam$toplot
  fit=plotparam$fit
  # Once we get the set of {p,s} values, we can run them through the s-shaped 
  # curve of selection
  nvar <- length(fit$fit)/2
  
  # generate sigmoidal (S-shaped) curves of selection
  scurves <- .scurves(p=fit$fit[1:nvar], s=fit$fit[-c(1:nvar)], ts=toplot$time)
  
  #if (any(!is.na(fit$sample))) {  
  # calculate 95% confidence intervals from sampled parameters
  s95 <- lapply(split(fit$sample, 1:nrow(fit$sample)), function(x) {
    row <- as.numeric(x)
    s <- .scurves(p=row[1:nvar], s=row[-c(1:nvar)], ts=toplot$time)
  })
  qcurve <- function(q) {
    sapply(1:ncol(scurves), function(i) {
      apply(sapply(s95, function(x) x[,i]), 1, 
            function(y) quantile(y, q)) 
    })
  } 
  lo95 <- qcurve(0.025)
  hi95 <- qcurve(0.975)  
  #}
  
  par(mfrow=c(1,1), mar=c(5,5,1,1))
  
  # display counts
  plot(toplot$date, toplot$n2/toplot$tot, xlim=c(min(toplot$date), max(toplot$date)), ylim=c(0, 1), 
       pch=21, col='black', bg=alpha(col[1], 0.7), cex=sqrt(toplot$n2)/5, 
       xlab="Sample collection date", 
       ylab=paste0("growth advantage (s% per day) relative to ",plotparam$ref[[1]]," (stricto)\nin ", plotparam$region, ", with 95% CI bars"))
  # show trendlines
  lines(toplot$date, scurves[,2])
  if (ncol(scurves) > 2) {
    lines(toplot$date, scurves[,3])
  }
  
  #if (!is.na(fit$sample)) {
  # display confidence intervals
  polygon(x=c(toplot$date, rev(toplot$date)), y=c(lo95[,2], rev(hi95[,2])),
          col=alpha(col[1], 0.5))
  if(ncol(lo95) > 2) {
    polygon(x=c(toplot$date, rev(toplot$date)), y=c(lo95[,3], rev(hi95[,3])),
            col=alpha(col[2], 0.5))
  }
  #}
  
  # report parameter estimates on plot
  str2 <- sprintf("%s: %s {%s, %s}", plotparam$mut[[1]],
                  format(round(fit$fit[["s1"]],3), nsmall=3), 
                  format(round(fit$confint["s1", "2.5 %"], 3), nsmall=3),
                  format(round(fit$confint["s1", "97.5 %"], 3), nsmall=3))
  text(x=toplot$date[1], y=0.95, str2, col=col[1], pos=4, cex = 1)
}
# Bends suggest a changing selection over time (e.g., due to the impact of 
# vaccinations differentially impacting the variants). Sharper turns are more 
# often due to NPI measures . 

