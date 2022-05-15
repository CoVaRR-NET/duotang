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


#' combine multiple PANGO lineages in a data set, summing counts
#' TODO: let user specify a regular expression?
.combine.lineages <- function(df) {
  df <- as.data.frame(
    unique(df %>% group_by(time) %>% transmute(
      day=sample.collection.date, n=sum(n), time=time, lineage=lineage
      )))
  df$lineage <- df$lineage[1]
  distinct(df)
}


.make.estimator <- function(region, startdate, reference, mutants) {
  # handle special values for prov
  if (region[1] == "East provinces (NL+NS+NB)") {
    prov <- c("Nova_Scotia", "New_Brunswick", "Newfoundland and Labrador")
  } else if (region[1] == "Canada") {
    prov <- unique(meta$geo_loc_name..state.province.territory.)
  } else if (region[1] == "Canada (no AB)") {
    provinces <- unique(meta$geo_loc_name..state.province.territory.)
    prov <- provinces[provinces != 'Alberta']
  } else {
    prov <- region
  }
  
  # filter metadata
  mydata <- meta %>% filter(
    lineage %in% c(reference, unlist(mutants)), 
    geo_loc_name..state.province.territory. %in% prov,
    !is.na(sample.collection.date),
    sample.collection.date >= startdate
    ) %>% group_by(sample.collection.date) %>% dplyr::count(lineage)
  
  # set final date
  lastdate <- max(mydata$sample.collection.date)
  
  # convert time to negative integers for fitting model (0 = last date)
  mydata$time <- as.numeric(difftime(mydata$sample.collection.date, lastdate, 
                                     units='days'))
  
  # separate by reference and mutant lineage(s)
  refdata <- .combine.lineages(filter(mydata, lineage %in% reference))
  mutdata <- lapply(mutants, function(mut) {
    .combine.lineages(filter(mydata, lineage%in% mut))
    })
  
  # generate time series
  timestart <- as.integer(startdate-lastdate)
  toplot <- data.frame(time=seq.int(from=timestart, to=0))
  toplot$n1 <- refdata$n[match(toplot$time, refdata$time)]
  
  temp <- lapply(mutdata, function(md) md$n[match(toplot$time, md$time)])  
  toplot <- cbind(toplot, temp)
  names(toplot) <- c('time', 'n1', paste('n', 1:length(mutdata)+1, sep=''))
  
  # Any NA's refer to no variant of that type on a day, set to zero
  toplot[is.na(toplot)] <- 0 
  
  # To aid in the ML search, we rescale time to be centered as close as possible
  # to the midpoint (p=0.5), to make sure that the alleles are segregating at 
  # the reference date.  If we set t=0 when p (e.g., n1/(n1+n2+n3)) is near 0 
  # or 1, then the likelihood surface is very flat.
  v <- apply(toplot[,-1], 1, function(ns) { 
    ifelse(sum(ns)>0, prod(ns) / sum(ns)^length(ns), 0) 
    })
  
  refdate <- which.max(smooth.spline(v[!is.na(v)])$y)
  #refdate <- which(v==max(v, na.rm=TRUE))[1]
  timeend <- -(timestart+refdate)
  timestart <- -refdate
  toplot$time <- seq.int(timestart,timeend)
  
  # apply same time scale to original datasets
  refdata$time <- refdata$time + (timeend-timestart)-refdate
  for (i in 1:length(mutdata)) {
    mutdata[[i]]$time <- mutdata[[i]]$time + (timeend-timestart)-refdate  
  }
  
  dateseq <- seq.Date(as.Date(startdate), as.Date(lastdate), "days")
  dateconverter <- data.frame(time=toplot$time, date=as.Date(dateseq))
  toplot$date <- dateconverter$date
  
  list(region=region, prov=prov, refdata=refdata, mutdata=mutdata, toplot=toplot)
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
.llfunc <- function(p, s, refdata, mutdata) {
  stopifnot(length(mutdata) == length(p) & length(p) == length(s))
  
  # ensure that all counts use the same time sequence
  ts <- unique(c(refdata$time, unlist(sapply(mutdata, function(md) md$time))))
  pr.vecs <- .scurves(p, s, ts)
  
  # convert counts into a matrix
  counts <- matrix(0, nrow=length(ts), ncol=1+length(p))
  counts[match(refdata$time, ts), 1] <- refdata$n
  for (j in 1:length(mutdata)) {
    counts[match(mutdata[[j]]$time, ts), j+1] <- mutdata[[j]]$n
  }
  
  # calculate log-likelihood (negative sign because optimizer minimizes)
  -sum(counts * log(pr.vecs))
}


# I had to write these wrapper functions because mle2 doesn't like vector 
# parameters >:(
.ll.trinom <- function(p1, p2, s1, s2, refdata, mutdata) {
  suppressWarnings(
    .llfunc(p=c(p1, p2), s=c(s1, s2), refdata=refdata, mutdata=mutdata)
  )
}

.ll.binom <- function(p1, s1, refdata, mutdata) {
  suppressWarnings(
    .llfunc(p=p1, s=s1, refdata=refdata, mutdata=mutdata)
    )
}


#' fit multinomial model to count data by maximum likelihood
#' @param obj:  data frame, time series for reference type
#' @param startpar:  list, initial parameter values
#' @param method:  character, name of method for call to optim(), defaults to 'BFGS'
#' @return  list, fit = object of class 'mle2'
#'                confint = matrix returned from confint
#'                sample = data frame from RandomHessianOrMCMC
.fit.model <- function(est, startpar, method="BFGS") {
  refdata <- est$refdata
  mutdata <- est$mutdata
  
  if (length(startpar$s) == 1) {
    bbml <- mle2(.ll.binom, start=list(p1=startpar$p[1], s1=startpar$s[1]), 
                 data=list(refdata=refdata, mutdata=mutdata[1]), method=method)  
  } 
  else if (length(startpar$s) == 2) {
    bbml <- mle2(.ll.trinom, 
                 start=list(p1=startpar$p[1], p2=startpar$p[2], 
                            s1=startpar$s[1], s2=startpar$s[2]), 
                 data=list(refdata=refdata, mutdata=mutdata), method=method)
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
  
  return(list(fit=bbfit, confint=myconf, sample=df))
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
plot.selection.files <- function(region, startdate, reference, mutants, startpar, 
                           col=c('red', 'blue'), method='BFGS', file=NA) {
  est <- .make.estimator(region, startdate, reference, mutants)
  toplot <- est$toplot
  toplot$tot <- apply(toplot[which(!is.element(names(toplot), c('time', 'date')))], 1, sum)
  fit <- .fit.model(est, startpar, method=method)
  
  # Once we get the set of {p,s} values, we can run them through the s-shaped 
  # curve of selection
  nvar <- length(fit$fit)/2
  
  # generate sigmoidal (S-shaped) curves of selection
  scurves <- .scurves(p=fit$fit[1:nvar], s=fit$fit[-c(1:nvar)], ts=toplot$time)
  
  if (any(!is.na(fit$sample))) {  
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
  }
  
  # write to a specific file
  if (!is.na(file)) {
    res <- 150
    png(file, width=10*res, height=5*res, res=res)
  }
  
  par(mfrow=c(1,2), mar=c(5,5,1,1))
  
  # display counts
  plot(toplot$date, toplot$n2/toplot$tot, xlim=c(min(toplot$date), max(toplot$date)), ylim=c(0, 1), 
       pch=21, col='black', bg=alpha(col[1], 0.7), cex=sqrt(toplot$n2)/5, 
       xlab="Sample collection date", 
       ylab=paste0("Proportion in ", est$region))
  if(!is.null(toplot$n3)) {
    points(toplot$date, toplot$n3/toplot$tot, pch=21, col='black', 
           bg=alpha(col[2], 0.7), cex=sqrt(toplot$n3)/5)
  }

  # show trendlines
  lines(toplot$date, scurves[,2])
  if (ncol(scurves) > 2) {
    lines(toplot$date, scurves[,3])
  }
  
  if (!is.na(fit$sample)) {
    # display confidence intervals
    polygon(x=c(toplot$date, rev(toplot$date)), y=c(lo95[,2], rev(hi95[,2])),
            col=alpha(col[1], 0.5))
    if(ncol(lo95) > 2) {
      polygon(x=c(toplot$date, rev(toplot$date)), y=c(lo95[,3], rev(hi95[,3])),
              col=alpha(col[2], 0.5))
    }
  }
  
  # report parameter estimates on plot
  str2 <- sprintf("%s: %s {%s, %s}", est$mutdata[[1]]$lineage[1],
                  format(round(fit$fit[["s1"]],3), nsmall=3), 
                  format(round(fit$confint["s1", "2.5 %"], 3), nsmall=3),
                  format(round(fit$confint["s1", "97.5 %"], 3), nsmall=3))
  text(x=toplot$date[1], y=0.95, str2, col=col[1], pos=4, cex = 1)
  
  if (length(mutants) > 1) {
    str3 <- sprintf("%s: %s {%s, %s}", est$mutdata[[2]]$lineage[1],
                    format(round(fit$fit[["s2"]], 3), nsmall=3), 
                    format(round(fit$confint["s2", "2.5 %"], 3), nsmall=3),
                    format(round(fit$confint["s2", "97.5 %"], 3), nsmall=3))    
    text(x=toplot$date[1], y=0.88, str3, col=col[2], pos=4, cex = 1)
  }
  
  
  # second plot - logit transform
  #options(scipen=5)  # use scientific notation for numbers exceeding 5 digits
  par(mar=c(5,5,1,1))
  
  plot(toplot$date, toplot$n2/toplot$n1, pch=21,
       bg=alpha(col[1], 0.7), cex=sqrt(toplot$n2)/3, xlim=c(min(toplot$date), max(toplot$date)), ylim=c(0.001, 1000), 
       xlab='Sample collection date',
       ylab=paste0("Logit in ", est$region), log='y', yaxt='n')
  axis(2, at=10^(-3:3), label=10^(-3:3), las=1, cex.axis=0.7)
  
  lines(toplot$date, scurves[,2] / scurves[,1])
  text(x=toplot$date[1], y=500, str2, col=col[1], pos=4, cex=1)
  
  if (!is.null(toplot$n3)) {
    # draw second series
    points(toplot$date, toplot$n3/toplot$n1, pch=21,
           bg=alpha(col[2], 0.7), cex=sqrt(toplot$n3)/3)
    lines(toplot$date, scurves[,3] / scurves[,1])
    text(x=toplot$date[1], y=200, str3, col=col[2], pos=4, cex=1)
  }
  
  if (!is.na(file)) dev.off()
  
  # Bends suggest a changing selection over time (e.g., due to the impact of 
  # vaccinations differentially impacting the variants). Sharper turns are more 
  # often due to NPI measures. 
}



