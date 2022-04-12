#' combine multiple PANGO lineages in a data set, summing counts
#' TODO: let user specify a regular expression?
.combine.lineages <- function(df) {
  df <- as.data.frame(
    unique(df %>% group_by(time) %>% transmute(
      day=sample.collection.date, n=sum(n), time=time, lineage=lineage
      )))
  df$lineage <- df$lineage[1]
  df
}


#' @param prov:  character, province name(s)
#' @param startdate:  Date, earliest sample collection date - should not be too
#'                    far before both alleles become common, or else rare 
#'                    migration events may skew estimation.
#' @param reference:  character, one or more PANGO lineage names, e.g., 
#'                    c("BA.1", "BA.2"), as a reference set (wildtype)
#' @param mutants:  list, one or more character vectors of PANGO lineage names 
#'                 to estimate selection advantages for.
#' @param col:  list, colours for plotting
#' @example 
#' reference <- c("BA.1")  # or c("BA.1", "BA.1.1")
#' mutants <- list("BA.1.1", "BA.2")
#' startdate<-as.Date("2021-12-15")
plot_selection_estimator <- function(prov, startdate, reference, mutants, col) {
  # handle special values for prov
  if (prov[1] == "East provinces (NL+NS+NB)") {
    prov <- c("Nova_Scotia", "New_Brunswick", "Newfoundland and Labrador")
  } else if (prov[1] == "Canada (no AB)") {
    provinces <- unique(meta$geo_loc_name..state.province.territory.)
    prov <- provinces[provinces != 'Alberta']
  }
  
  # filter metadata
  mydata <- meta %>% filter(
    lineage %in% c(reference, unlist(mutants)), 
    geo_loc_name..state.province.territory. %in% prov,
    !is.na(sample.collection.date),
    sample.collection.date >= startdate
    ) %>% group_by(sample.collection.date) %>% count(lineage)
  
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
  # the reference date.  If we set t=0 when p is near 0 or 1, then the 
  # likelihood surface is very flat.
  v <- apply(toplot[,-1], 1, prod)
  
  refdate <- which(v==max(v, na.rm=TRUE))[1]
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
  
  startp <- 0.5
  
  
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

  # calculate exponential growths (N e^{st}) over time, where N is replaced 
  # by p with some scaling constant we can ignore
  p.vecs <- matrix(NA, nrow=length(ts), ncol=1+length(p))
  p.vecs[,1] <- rep(1-sum(p), length(ts))  # s=0 for reference, exp(0*t) = 1 for all t
  for (j in 1:length(mutdata)) {
    p.vecs[,j+1] <- p[j] * exp(s[j] * ts)
  }
  pr.vecs <- p.vecs / apply(p.vecs, 1, sum)  # normalize to probabilities
  
  # convert counts into a matrix
  counts <- matrix(0, nrow=length(ts), ncol=1+length(p))
  counts[match(refdata$time, ts), 1] <- refdata$n
  for (j in 1:length(mutdata)) {
    counts[match(mutdata[[j]]$time, ts), j+1] <- mutdata[[j]]$n
  }
  
  # calculate log-likelihood (negative sign because optimizer minimizes)
  -sum(counts * log(pr.vecs))
}


.ll.trinom <- function(p1, p2, s1, s2, refdata, mutdata) {
  # wrapper required because mle2 doesn't like vector parameters >:(
  .llfunc(p=c(p1, p2), s=c(s1, s2), refdata=refdata, mutdata=mutdata)
}

.ll.binom <- function(p1, s1, refdata, mutdata) {
  .llfunc(p=p1, s=s1, refdata=refdata, mutdata=mutdata)
}

#' fit multinomial model to count data by maximum likelihood
#' @param startpar:  list, initial parameter values
#' @param refdata:  data frame, time series for reference type
#' @param mutdata:  list, data frames for every additional type
#' @example 
#' startpar <- list(p=c(0.5, 0.05), s=c(0.1, 0.1))
.fit.model <- function(startpar, refdata, mutdata) {
  if (length(startpar$s) == 1) {
    bbml <- mle2(.ll.binom, start=list(p1=startpar$p[1], s1=startpar$s[1]), 
                 data=list(refdata=refdata, mutdata=mutdata[1]))  
  } 
  else if (length(startpar$s) == 2) {
    bbml <- mle2(.ll.trinom, 
                 start=list(p1=startpar$p[1], p2=startpar$p[2], 
                            s1=startpar$s[1], s2=startpar$s[2]), 
                 data=list(refdata=refdata, mutdata=mutdata))  
  }
  else {
    stop("ERROR: function does not currently support more than three types!")
  }
  
  
  # based on the quadratic approximation at the maximum likelihood estimate
  myconf <- confint(bbml,method="quad")
  
}





