#' Original implementation in Mathematica by Sarah Otto
#' First port into R by Carmen Murall and Sarah Otto
#' Refactored by Art Poon
suppressMessages({
  require(bbmle, quietly=T)
  require(HelpersMG, quietly=T)
  require(dplyr, quietly=T)
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
      day=sample_collection_date, n=sum(n), time=time, lineage=lineage
      )))
  df$lineage <- df$lineage[1]
  distinct(df)
}


.make.estimator <- function(region, startdate, reference, mutants) {
  # handle special values for prov
  if (region[1] == "East provinces (NL+NS+NB)") {
    prov <- c("Nova Scotia", "New Brunswick", "Newfoundland and Labrador")
  } else if (region[1] == "Canada") {
    prov <- unique(meta$province)
  } else if (region[1] == "Canada (no AB)") {
    provinces <- unique(meta$province)
    prov <- provinces[provinces != 'Alberta']
  } else {
    prov <- region
  }
  
  # filter metadata
  mydata <- meta %>% filter(
    lineage %in% c(reference, unlist(mutants)), 
    province %in% prov,
    !is.na(sample_collection_date),
    sample_collection_date >= startdate
    ) %>% group_by(sample_collection_date) %>% dplyr::count(lineage)
  
  # set final date
  lastdate <- max(mydata$sample_collection_date)
  
  # convert time to negative integers for fitting model (0 = last date)
  mydata$time <- as.numeric(difftime(mydata$sample_collection_date, lastdate, 
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
  #v <- apply(toplot[,-1], 1, function(ns) { 
  #  ifelse(sum(ns)>0, prod(ns) / sum(ns)^length(ns), 0) 
  #  })
  v <- apply(toplot[,-1], 1, function(ns) {
    ifelse(sum(ns)>10, prod(ns) / sum(ns)^length(ns), 0)
  })
  
  #refdate <- which.max(smooth.spline(v[!is.na(v)])$y)
  refdate <- which.max(smooth.spline(v[!is.na(v)],nknots=10)$y)
  #refdate <- which.max(smooth.spline(v[!is.na(v)],w=toplot$n1,nknots=10)$y)
  
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
.ll.quadnom <- function(p1, p2, p3, s1, s2, s3, refdata, mutdata) {
  suppressWarnings(
    .llfunc(p=c(p1, p2, p3), s=c(s1, s2, s3), refdata=refdata, mutdata=mutdata)
  )
}

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
  }  else if (length(startpar$s) == 3) {
    bbml <- mle2(.ll.quadnom, 
                 start=list(p1=startpar$p[1], p2=startpar$p[2], p3=startpar$p[3], 
                            s1=startpar$s[1], s2=startpar$s[2], s3=startpar$s[3]), 
                 data=list(refdata=refdata, mutdata=mutdata), method=method)
  } else {
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


#' DEPRECATED. Fit selection model and generate a plot
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
# region <- "Canada"
# startdate <- as.Date(max(meta$sample_collection_date)-days(120))
# reference <- c(setAll)  # or c("BA.1", "BA.1.1")
# mutants <- list(sublineages_BA5,sublineages_BQ)
# names <- list("BA.5*","BQ*","the rest")
# startpar <- startpar3
# method='BFGS'
# maxdate=NA
# col=c('red', 'blue')
plot.selection.estimate <- function(region, startdate, reference, mutants, names=list(NA),
                                    startpar, maxdate=NA, col=c('red', 'blue'), method='BFGS') {

  est <- .make.estimator(region, startdate, reference, mutants)
  toplot <- est$toplot
  toplot$tot <- apply(toplot[which(!is.element(names(toplot), c('time', 'date')))], 1, sum)
  fit <- .fit.model(est, startpar, method=method)
  
  # Once we get the set of {p,s} values, we can run them through the s-shaped 
  # curve of selection
  nvar <- length(fit$fit)/2
  
  # generate sigmoidal (S-shaped) curves of selection
  scurves <- .scurves(p=fit$fit[1:nvar], s=fit$fit[-c(1:nvar)], ts=c(toplot$time))#, seq(38,99)))
  scurves.extended<- .scurves(p=fit$fit[1:nvar], s=fit$fit[-c(1:nvar)], ts=c(toplot$time, seq(max(toplot$time)+1,(max(toplot$time)+100))))#, ))
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
  
  par(mar=c(5,5,1,1))
  if(is.na(maxdate)){
    maxdate=max(toplot$date)
  }

  #diplay counts
  plot(toplot$date, toplot$n2/toplot$tot, xlim=c(min(toplot$date), maxdate), ylim=c(0, 1), 
       pch=21, col='black', bg=alpha(col[1], 0.7), cex=sqrt(toplot$n2)/10, 
       xlab="Sample collection date", 
       ylab=paste0("Proportion in ", est$region))
  #lab=paste0("Growth advantage (s% per day) relative\nto BA.5.2 with 95% CI bars in ", est$region))
  if(!is.null(toplot$n3)) {
    points(toplot$date, toplot$n3/toplot$tot, pch=21, col='black', 
           bg=alpha(col[2], 0.7), cex=sqrt(toplot$n3)/10)
  }
  # show trendlines
  lines(toplot$date, scurves[,2])
  if (ncol(scurves) > 2) {
    lines(toplot$date, scurves[,3])
  }
  
  if (any(!is.na(fit$sample))) {  
    # display confidence intervals
    polygon(x=c(toplot$date, rev(toplot$date)), y=c(lo95[,2], rev(hi95[,2])),
            col=alpha(col[1], 0.5))
    if(ncol(lo95) > 2) {
      polygon(x=c(toplot$date, rev(toplot$date)), y=c(lo95[,3], rev(hi95[,3])),
              col=alpha(col[2], 0.5))
    }
  }
  
  # report parameter estimates on plot
  if(is.na(names[[1]])){name=est$mutdata[[1]]$lineage[1]}
  else{name=names[[1]]}
  str2 <- sprintf("%s: %s {%s, %s}", name,
                  format(round(fit$fit[["s1"]],3), nsmall=3), 
                  format(round(fit$confint["s1", "2.5 %"], 3), nsmall=3),
                  format(round(fit$confint["s1", "97.5 %"], 3), nsmall=3))
  text(x=toplot$date[1], y=0.59, str2, col=col[1], pos=4, cex = 1)
  
  if (length(mutants) > 1) {
    if(is.na(names[[1]])){name=est$mutdata[[2]]$lineage[1]}
    else{name=names[[2]]}
    str3 <- sprintf("%s: %s {%s, %s}", name,
                    format(round(fit$fit[["s2"]], 3), nsmall=3), 
                    format(round(fit$confint["s2", "2.5 %"], 3), nsmall=3),
                    format(round(fit$confint["s2", "97.5 %"], 3), nsmall=3))    
    text(x=toplot$date[1], y=0.52, str3, col=col[2], pos=4, cex = 1)
  }  
  str4=sprintf("Relative to %s*",names[[3]])
  text(x=toplot$date[1], y=0.45,str4, col="black", pos=4, cex = 1)
  
  
  # second plot - logit transform
  #options(scipen=5)  # use scientific notation for numbers exceeding 5 digits
  par(mar=c(5,5,1,1))
  
  plot(toplot$date, toplot$n2/toplot$n1, pch=21,
       bg=alpha(col[1], 0.7), cex=sqrt(toplot$n2)/10, xlim=c(min(toplot$date), maxdate), ylim=c(0.001, 1000), 
       xlab='Sample collection date',
       ylab=paste0("Logit in ", est$region), log='y', yaxt='n')
  axis(2, at=10^(-3:3), label=10^(-3:3), las=1, cex.axis=0.7)
  
  lines(toplot$date, scurves[,2] / scurves[,1])
  text(x=toplot$date[1], y=500, str2, col=col[1], pos=4, cex=1)
  
  if (!is.null(toplot$n3)) {
    # draw second series
    points(toplot$date, toplot$n3/toplot$n1, pch=21,
           bg=alpha(col[2], 0.7), cex=sqrt(toplot$n3)/10)
    lines(toplot$date, scurves[,3] / scurves[,1])
    text(x=toplot$date[1], y=200, str3, col=col[2], pos=4, cex=1)
  }
  str4=sprintf("Relative to %s*",names[[3]])
  text(x=toplot$date[1], y=90,str4, col="black", pos=4, cex = 1)

  return(list("date"=max(toplot$date), "fit"=fit, "scurves" = scurves, "scurvesExtended" = scurves.extended, "names" = names, "color"=col, "region"=region, "plot"=p))
  # Bends suggest a changing selection over time (e.g., due to the impact of 
  # vaccinations differentially impacting the variants). Sharper turns are more 
  # often due to NPI measures. 
}

#' This function is a refactor of plot.selection.estimate() to make use of ggplot2 and returns data as a named list rather than just plotting it for better error handling.
#' Return a named list containing the region, fit model, scurve, projectscurve, mutantNames, mutant colors, plot1 and logit plot2 )))
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
plot.selection.estimate.ggplot <- function(region, startdate, reference, mutants, names=list(NA),
                                    startpar, maxdate=NA, col=c('red', 'blue'), method='BFGS') {
  #region <- "Quebec"
  #startdate <- as.Date(max(meta$sample_collection_date)-days(120))
  #reference <- c(setAll)  # or c("BA.1", "BA.1.1")
  #mutants <- mutants
  #names <- mutantNames
  #startpar <- startpar
  #method='BFGS'
  #maxdate=NA
  #col=col
  
  
  est <- .make.estimator(region, startdate, reference, mutants)
  toplot <- est$toplot
  toplot$tot <- apply(toplot[which(!is.element(names(toplot), c('time', 'date')))], 1, sum)
  fit <- .fit.model(est, startpar, method=method)
  # Once we get the set of {p,s} values, we can run them through the s-shaped 
  # curve of selection
  nvar <- length(fit$fit)/2
  
  # generate sigmoidal (S-shaped) curves of selection
  scurves <- .scurves(p=fit$fit[1:nvar], s=fit$fit[-c(1:nvar)], ts=c(toplot$time))#, seq(38,99)))
  scurves.extended<- .scurves(p=fit$fit[1:nvar], s=fit$fit[-c(1:nvar)], ts=c(toplot$time, seq(max(toplot$time)+1,(max(toplot$time)+100))))#, ))
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
  
  par(mar=c(5,5,1,1))
  if(is.na(maxdate)){
    maxdate=max(toplot$date)
  }
  # format the count data (circles)
  plotData <- toplot %>% melt(id = c("date", "time", "tot")) %>% dplyr::select(date, variable, value, tot) %>% 
    filter(variable != "n1") %>% mutate (variable = str_extract(variable,"[^n]+$")) %>% 
    mutate (p = value/tot) %>% mutate(p=ifelse(is.nan(p),0,p)) %>% dplyr::select(-tot) %>%
    rowwise() %>% mutate (s = (fit$fit[[paste0("s", (as.numeric(variable)-1))]])) %>% group_by(variable) %>% mutate(n = sum(value)) %>% 
    mutate(variable = paste0(names[as.numeric(variable)-1], "(n=", n, "): ", round(fit$fit[paste0("s", as.numeric(variable)-1)],2), " {", round(fit$confint[paste0("s", as.numeric(variable)-1), "2.5 %"], 3), ", ", round(fit$confint[paste0("s", as.numeric(variable)-1), "97.5 %"], 3), "}")) #THIS LINE IS CLEARLY WRONG
  plotData$variable =  as.factor(plotData$variable)
  
  #plot the count data (circles)
  p<- ggplot() +
    geom_point(data = plotData, mapping = aes(x = date, y=p,  fill = variable), pch=21, color = "black", alpha=0.7, size = sqrt(plotData$value)/4) +
    scale_fill_manual(label = c(levels(plotData$variable)), values = unname(col)) +
    xlab("Sample collection date") +
    ylab(paste0("Proportion in ", est$region)) + 
    ylim(0,1) +
    xlim(min(plotData$date), maxdate)
  
  #format the fit (line)
  scurvesPlotData <- cbind(toplot[,"date", drop=F], scurves[,2:ncol(scurves)])
  colnames(scurvesPlotData) <- c("date", levels(plotData$variable))
  scurvesPlotData=scurvesPlotData %>% melt(id="date")
  
  #plot the VOC fits (line)
  p <- p + geom_line(data = scurvesPlotData, mapping = aes(x=date, y=value, color=variable)) +
    scale_color_manual(label = c(levels(scurvesPlotData$variable)), values = unname(col)) 
  
  if (any(!is.na(fit$sample))) {  
    p <- p + geom_ribbon(data = toplot, mapping = aes(x=date, ymin=lo95[,2], ymax=hi95[,2]), color = "black", fill= col[1], alpha=0.5)
    if(ncol(lo95) > 2) {
      for (i in seq(3,ncol(lo95))){
        p <- p + geom_ribbon(data = toplot, mapping = aes(x=date, ymin=lo95[,i], ymax=hi95[,i]), color = "black", fill=col[i-1], alpha=0.5)
      }
    }
  }
  
  #define theme
  p<-p + theme_bw() +     
    labs(caption = paste0("*Relative to the rest","\nMost recent data date: ", maxdate)) + 
    theme(legend.position=c(0.35, 0.90), legend.title=element_blank(), 
          legend.text=element_text(size=20), 
          legend.background = element_blank(), 
          legend.key=element_blank(),
          legend.spacing.y = unit(0.5, "cm"),
          legend.key.size = unit(2, "cm"),
          text = element_text(size = 20)) 
  
  # second plot - logit transform
  options(scipen=1000000)

  # format the count data (circles)
  plotData <- toplot %>% melt(id = c("date", "time", "n1")) %>% dplyr::select(date, variable, value, n1) %>% 
    filter(variable != "tot") %>% mutate (variable = str_extract(variable,"[^n]+$")) %>% 
    mutate (p = value/n1) %>% filter(p != Inf) %>% dplyr::select(-n1) %>%
    rowwise() %>% mutate (s = (fit$fit[[paste0("s", (as.numeric(variable)-1))]]))  %>% group_by(variable) %>% mutate(n = sum(value)) %>% 
    mutate(variable = paste0(names[as.numeric(variable)-1], "(n=", n, "): ",round(fit$fit[paste0("s", as.numeric(variable)-1)],2), " {", round(fit$confint[paste0("s", as.numeric(variable)-1), "2.5 %"], 3), ", ", round(fit$confint[paste0("s", as.numeric(variable)-1), "97.5 %"], 3), "}")) #THIS LINE IS CLEARLY WRONG
  plotData$variable =  as.factor(plotData$variable)
  
  # plot the count data (circles)
  p2<- ggplot() +
    geom_point(data = plotData, mapping = aes(x = date, y=p,  fill = variable), pch=21, color = "black", alpha=0.7, size = sqrt(plotData$value)/4) +
    scale_fill_manual(label = c(levels(plotData$variable)), values = unname(col)) +
    xlab("Sample collection date") +
    ylab(paste0("Proportion in ", est$region)) + 
    scale_y_log10(limits=c(0.001,1000), breaks = c(0.001, 0.01, 0.1, 1, 10, 100, 1000), labels = c(0.001, 0.01, 0.1, 1, 10, 100, 1000)) +
    xlim(min(plotData$date), maxdate)
  
  # format the fits (lines)
  scurvesPlotData <- cbind(toplot[,"date", drop=F], (scurves[,2:ncol(scurves)]/scurves[,1]))
  colnames(scurvesPlotData) <- c("date", levels(plotData$variable))
  scurvesPlotData=scurvesPlotData %>% melt(id=c("date"))
  # plot the fits (lines)
  p2 <- p2 + geom_line(data = scurvesPlotData, mapping = aes(x=date, y=value, color=variable)) +
    scale_color_manual(label = c(levels(scurvesPlotData$variable)), values = unname(col)) 
  
  #define plot theme
  p2<-p2 + theme_bw() + 
    labs(caption = paste0("*Relative to the rest","\nMost recent data date: ", maxdate)) + 
    theme(legend.position=c(0.35, 0.90), legend.title=element_blank(), 
          legend.text=element_text(size=20), 
          legend.background = element_blank(), 
          legend.key=element_blank(),
          legend.spacing.y = unit(0.5, "cm"),
          legend.key.size = unit(2, "cm"),
          text = element_text(size = 20)) 

  #returns all the necessary information as a named list. 
  return(list("date"=max(toplot$date), "fit"=fit, "scurves" = scurves, "scurvesExtended" = scurves.extended, "names" = names, "color"=col, "region"=region, "plot1"=p, "plot2"=p2))
  # Bends suggest a changing selection over time (e.g., due to the impact of 
  # vaccinations differentially impacting the variants). Sharper turns are more 
  # often due to NPI measures. 
}

#DEPRECATED. function used to generate the single variant selection plots.
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

#' This function is a refactor of plot.selection() to make use of ggplot2 and returns the plot object rather than just plotting it for better error handling.
#' Return a ggplot2 plot.
#' @param plotparam:  The selection estimate object. e.g 1 entry in allparam
#' @param maxdate:  the right limit date that should be used for the plots. 
plotIndividualSelectionPlots.ggplot <- function(plotparam, maxdate, col=c('red', 'blue')) {
  toplot=plotparam$toplot
  fit=plotparam$fit
  # Once we get the set of {p,s} values, we can run them through the s-shaped 
  # curve of selection
  nvar <- length(fit$fit)/2
  # generate sigmoidal (S-shaped) curves of selection
  scurves <- .scurves(p=fit$fit[1:nvar], s=fit$fit[-c(1:nvar)], ts=toplot$time)
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
  par(mfrow=c(1,1), mar=c(5,5,1,1))
  
  #format the count 
  variantName <- plotparam$mut[[1]]
  variantRef <- plotparam$ref[[1]]
  plotData <- toplot %>% melt(id = c("date", "time", "tot")) %>% dplyr::select(date, variable, value, tot) %>% 
    filter(variable != "n1") %>% mutate (variable = str_extract(variable,"[^n]+$")) %>% 
    mutate (p = value/tot) %>% mutate(p=ifelse(is.nan(p),0,p)) %>% dplyr::select(-tot) %>%
    rowwise() %>% mutate (s = (fit$fit[[paste0("s", (as.numeric(variable)-1))]])) %>% group_by(variable) %>% mutate(n = sum(value)) %>% 
    mutate(variable = paste0(variantName, "(n=", n, "): ", round(fit$fit[paste0("s", as.numeric(variable)-1)],2), " {", round(fit$confint[paste0("s", as.numeric(variable)-1), "2.5 %"], 3), ", ", round(fit$confint[paste0("s", as.numeric(variable)-1), "97.5 %"], 3), "}")) #THIS LINE IS CLEARLY WRONG
  plotData$variable =  as.factor(plotData$variable)

  #plot the count data (circles)
  p<- ggplot() +
    geom_point(data = plotData, mapping = aes(x = date, y=p,  fill = variable), pch=21, color = "black", alpha=0.7, size = sqrt(plotData$value)/4) +
    #scale_fill_manual(label = c(levels(plotData$variable)), c(col))  +
    xlab("Sample collection date") +
    ylab(paste0("growth advantage (s% per day) \nrelative to", variantRef, " (stricto) in ", plotparam$region)) + 
    ylim(0,1) +
    xlim(min(plotData$date), maxdate)
  
  #format the fit (line)
  scurvesPlotData <- cbind(toplot[,"date", drop=F], scurves[,2:ncol(scurves)])
  colnames(scurvesPlotData) <- c("date", levels(plotData$variable))
  scurvesPlotData=scurvesPlotData %>% melt(id="date")
  
  #plot the fit (line)
  p <- p + geom_line(data = scurvesPlotData, mapping = aes(x=date, y=value, color=variable)) 
#    scale_color_manual(label = c(levels(scurvesPlotData$variable)), values = c("red")) 
  
  if (any(!is.na(fit$sample))) {  
    p <- p + geom_ribbon(data = toplot, mapping = aes(x=date, ymin=lo95[,2], ymax=hi95[,2]), color = "black", fill= col[1], alpha=0.5)
    if(ncol(lo95) > 2) {
      for (i in seq(3,ncol(lo95))){
        p <- p + geom_ribbon(data = toplot, mapping = aes(x=date, ymin=lo95[,i], ymax=hi95[,i]), color = "black", fill=col[i-1], alpha=0.5)
      }
    }
  }
  
  #define theme
  p<-p + theme_bw() +     
    #labs(caption = paste0("Most recent data date: ", max(plotData$date))) + 
    theme(legend.position=c(0.45, 0.90), legend.title=element_blank(), 
          legend.text=element_text(size=12), 
          legend.background = element_blank(), 
          legend.key=element_blank(),
          legend.spacing.y = unit(0.5, "cm"),
          legend.key.size = unit(2, "cm"),
          text = element_text(size = 20)) 
  
  #plotData$lines<-scurvesPlotData$value
  #plotData <- plotData %>% dplyr::select(date, variable, value, lines)
  #colnames(plotData) <- c("date", "variable", "points", "lines")
  return(p)
  
  #return(list("plot" = p, "data" = plotData))

}

