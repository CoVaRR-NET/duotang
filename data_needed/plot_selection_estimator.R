suppressMessages(suppressWarnings(library(tidytree)))
suppressMessages(suppressWarnings(library(bbmle)))
suppressMessages(suppressWarnings(library(HelpersMG)))


plot_selection_estimator <- function(prov,startdate,name1,name2,name3) {
  mydata=metaCANall %>% filter(grepl("BA.", Pango_lineage), province == prov, !is.na(Collection_date), Collection_date >= startdate) %>% group_by(Collection_date) %>% count(Pango_lineage)
  if(prov=="East provinces (NL+NS+NB+ON+QC)"){
    mydata= metaCANall %>% filter(grepl("BA.", Pango_lineage), province %in% list("Nova_Scotia","New_Brunswick","Newfoundland_and_Labrador","Quebec","Ontario"), !is.na(Collection_date), Collection_date >= startdate) %>% group_by(Collection_date) %>% count(Pango_lineage)
  }
  if(prov=="Canada (no AB)"){
    mydata=metaCANall %>% filter(grepl("BA.", Pango_lineage), province != "Alberta", !is.na(Collection_date), Collection_date >= startdate) %>% group_by(Collection_date) %>% count(Pango_lineage)
  }
  
  #Set the final date:
  lastdate<-max(mydata$Collection_date)
  
  #convert time to an integer counter for use in fitting, first using the last date as time 0:
  mydata$time = as.numeric(difftime(mydata$Collection_date, lastdate, units = "days"))
  
  #filter data to after that starting date
  data1 <- filter(mydata, Pango_lineage %in% name1)
  data2 <- filter(mydata, Pango_lineage %in% name2)
  data3 <- filter(mydata, Pango_lineage %in% name3)
  
  #allow multiple Pango lineages to be combined if name1 or name2 includes a list, summing n
  data1 <- as.data.frame(unique(data1 %>% group_by(time) %>% transmute(day=Collection_date,  n=sum(n), time=time)))
  data2 <- as.data.frame(unique(data2 %>% group_by(time) %>% transmute(day=Collection_date,  n=sum(n), time=time)))
  data3 <- as.data.frame(unique(data3 %>% group_by(time) %>% transmute(day=Collection_date,  n=sum(n), time=time)))
  name1 <- name1[[1]]
  name2 <- name2[[1]]
  name3 <- name3[[1]]
  data1$Pango_lineage <- name1
  data2$Pango_lineage <- name2
  data3$Pango_lineage <- name3
  
  #join lists in a dataframe to plot proportions and represent time as a list of integers
  timestart<-as.numeric(difftime(startdate, lastdate, units = "days"))
  timeend<-as.numeric(difftime(lastdate, lastdate, units = "days"))
  toplot <- data.frame(time = seq.int(timestart,timeend))
  toplot$n1 <- data1$n[match(toplot$time,data1$time)]
  toplot$n2 <- data2$n[match(toplot$time,data2$time)]
  toplot$n3 <- data3$n[match(toplot$time,data3$time)]
  toplot[is.na(toplot)] = 0 #Any NA's refer to no variant of that type on a day, set to zero
  
  
  #To aid in the ML search, we rescale time to be centered as close as possible
  #to the midpoint for the second variable (p=0.5), to make sure that the alleles 
  #are segregating at the reference date.
  #If we set t=0 when p is near 0 or 1, then the likelihood surface is very flat.
  v=toplot$n1*toplot$n2*toplot$n3
  refdate<-which(v==max(v,na.rm=TRUE))
  refdate<-refdate[[1]] #Just in case there is more than one matching point, the first is taken
  timeend <- (timeend-timestart)-refdate
  timestart <- -refdate
  toplot$time <- seq.int(timestart,timeend)
  data1$time <- data1$time + (timeend-timestart)-refdate
  data2$time <- data2$time + (timeend-timestart)-refdate
  data3$time <- data3$time + (timeend-timestart)-refdate
  
  #date converter
  dateseq <- seq.Date(startdate,lastdate,"days")
  dateconverter <- data.frame(time=toplot$time,date=dateseq)
  
  # plot(y=toplot$n2/(toplot$n1+toplot$n2+toplot$n3),x=toplot$time,xlab="Time",ylab="proportion",ylim=c(0,1),col=col2)
  # points(y=toplot$n3/(toplot$n1+toplot$n2+toplot$n3),x=toplot$time,xlab="Time",ylab="proportion",cex=0.5,col=col3)
  #With time started in this way, we can use 0.5 as the frequency at t=0 (startp):
  startp <- 0.5
  #To get an estimate for the initial p value to try, we average the last 10 points before refdate
  #tempforp <- which(0 == data2$time)
  #startp <- mean(toplot$n2[(tempforp-9):tempforp])/(mean(toplot$n1[(tempforp-9):tempforp])+mean(toplot$n2[(tempforp-9):tempforp]))
  
  ##############################
  # Likelihood with two types
  ##############################
  ################################
  # Using mle2 and profile in BBMLE
  ################################
  #Alternatively, it looks like the BBMLE package performs well and gives
  #confidence intervals for the parameters.  Here, we have to flip the sign
  #of the log-likelihood directly for use with mle2 (can't send control=list(fnscale=-1) through?).
  trifunc <- function(p2,p3,s2,s3){
    -(sum(data1$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1$time)+p3*exp(s3*data1$time))))+
        sum(data2$n*log(p2*exp(s2*data2$time)/((1-p2-p3)+p2*exp(s2*data2$time)+p3*exp(s3*data2$time))))+
        sum(data3$n*log(p3*exp(s3*data3$time)/((1-p2-p3)+p2*exp(s2*data3$time)+p3*exp(s3*data3$time)))))
  }
  startpar<-list(p2=startp, p3=0.05, s2=0.1, s3=0.1)
  bbml<-mle2(trifunc, start = startpar)
  bbml
  #lnL
  bbml.value<--bbml@min
  
  #These confidence intervals are similar (I PREFER uniroot based on the profile likelihood procedure)
  #confint(bbml) # based on inverting a spline fit to the profile 
  
  myconf<-confint(bbml,method="quad") # based on the quadratic approximation at the maximum likelihood estimate
  
 # myconf<-confint(bbml,method="uniroot") # based on root-finding to find the exact point where the profile crosses the critical level

  #Interesting way of profiling the likelihood
  #bbprofile<-profile(bbml)
  #plot(bbprofile)
  #proffun(bbml)
  
  ################################
  # Drawing random parameters for CI
  ################################
  #We can draw random values for the parameters from the Hessian to determine the
  #variation in {p,s} combinations consistent with the data using RandomFromHessianOrMCMC.
  
  
  
  #We can also generate confidence intervals accounting for uncertainty in all parameters 
  #by drawing from the covariance matrix estimated from the Hessian (the matrix of double derivatives
  #describing the curvature of the likelihood surface near the ML peak).
  bbfit<-c(p2=bbml@details[["par"]][["p2"]],p3=bbml@details[["par"]][["p3"]],
           s2=bbml@details[["par"]][["s2"]],s3=bbml@details[["par"]][["s3"]])
  bbfit
  bbhessian<-bbml@details[["hessian"]]
  colnames(bbhessian) <- c("p2","p3","s2","s3")
  rownames(bbhessian) <- c("p2","p3","s2","s3")
  bbhessian
  
  df <- RandomFromHessianOrMCMC(Hessian=(bbhessian), 
                                fitted.parameters=bbfit, 
                                method="Hessian",replicates=1000)$random
  
  #Once we get the set of {p,s} values, we can run them through the s-shaped curve of selection
  scurve1 <- function(p2,p3,s2,s3){
    (p2*exp(s2*toplot$time)/((1-p2-p3)+p2*exp(s2*toplot$time)+p3*exp(s3*toplot$time)))
  }
  
  scurve2 <- function(p2,p3,s2,s3){
    (p3*exp(s3*toplot$time)/((1-p2-p3)+p2*exp(s2*toplot$time)+p3*exp(s3*toplot$time)))
  }
  
  #Generating a list of frequencies at each time point given each {p,s} combination
  #NOTE - We could run more time points, if projections into the future were desired just by 
  #extending toplot$time
  setofcurves2 <- t(mapply(scurve1,df[,1],df[,2],df[,3],df[,4]))
  setofcurves3 <- t(mapply(scurve2,df[,1],df[,2],df[,3],df[,4]))
  
  #95% innerquantiles
  lowercurve1 <- c()
  uppercurve1 <- c()
  lowercurve2 <- c()
  uppercurve2 <- c()
  for (tt in 1:length(toplot$time))  {
    lower1<-quantile(setofcurves2[,tt],0.025)
    upper1<-quantile(setofcurves2[,tt],0.975)
    lowercurve1<-append(lowercurve1,lower1)
    uppercurve1<-append(uppercurve1,upper1)
    
    lower2<-quantile(setofcurves3[,tt],0.025)
    upper2<-quantile(setofcurves3[,tt],0.975)
    lowercurve2<-append(lowercurve2,lower2)
    uppercurve2<-append(uppercurve2,upper2)
  }
  #add date column
  toplot$date <- dateconverter$date
  
  #A graph with 95% quantiles based on the Hessian draws.
  col2=pal[paste0("Omicron ",name2)]
  col3=pal[paste0("Omicron ",name3)]
  #png(file=paste0("curves_",i,".png"))
  plot(y=uppercurve1,x=toplot$date,type="l",xlab="",ylab=paste0("proportion in ",prov),ylim=c(0,1))
  points(y=toplot$n2/(toplot$n1+toplot$n2+toplot$n3),x=toplot$date,pch=21, col = "black", bg = alpha(col2, 0.7), cex=sqrt(toplot$n2)/3)#cex=(toplot$n2/log(10))/20)#cex=toplot$n2/50 )#cex = 0.5)
  points(y=toplot$n3/(toplot$n1+toplot$n2+toplot$n3),x=toplot$date,pch=21, col = "black", bg = alpha(col3, 0.7), cex=sqrt(toplot$n3)/3)#, cex=(toplot$n3/log(10))/20) #cex=toplot$n3/50 )#cex = 0.5)
  polygon(c(toplot$date, rev(toplot$date)), c(lowercurve1, rev(uppercurve1)),col = alpha(col2, 0.5))
  polygon(c(toplot$date, rev(toplot$date)), c(lowercurve2, rev(uppercurve2)),col = alpha(col3, 0.5))
  lines(y=(bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)/((1-bbfit[["p2"]]-bbfit[["p3"]])+bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)+bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time))),
        x=toplot$date,type="l")
  lines(y=(bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time)/((1-bbfit[["p2"]]-bbfit[["p3"]])+bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)+bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time))),
        x=toplot$date,type="l")
  str2=sprintf("%s: %s {%s, %s}",name2,format(round(bbfit[["s2"]],3),nsmall=3),format(round(myconf["s2","2.5 %"],3),nsmall=3),format(round(myconf["s2","97.5 %"],3),nsmall=3))
  str3=sprintf("%s: %s {%s, %s}",name3,format(round(bbfit[["s3"]],3),nsmall=3),format(round(myconf["s3","2.5 %"],3),nsmall=3),format(round(myconf["s3","97.5 %"],3),nsmall=3))
  text(x=toplot$date[1],y=0.95,str2,col = col2,pos=4, cex = 1)
  text(x=toplot$date[1],y=0.90,str3,col = col3,pos=4, cex = 1)
  #dev.off()
  
  ################################
  # Looking for a breakpoint
  ################################
  # Visually looking for breaks in the slope over time (formal breakpoint search
  # is in the two variant code).
  
  #png(file=paste0("logit_",i, ".png"))
  options( scipen = 5 )
  plot(y=toplot$n2/toplot$n1,x=toplot$date, pch=21, col = "black", bg = alpha(col2, 0.7), cex=sqrt(toplot$n2)/3,
       log="y",ylim=c(0.001,1000), yaxt = "n", xlab="",ylab=paste0("logit in ",prov))
  points(y=toplot$n3/toplot$n1,x=toplot$date, pch=21, col = "black", bg = alpha(col3, 0.7), cex=sqrt(toplot$n3)/3)
  lines(y=(bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)/(1-bbfit[["p2"]]-bbfit[["p3"]])),
        x=toplot$date, type="l",col="black")#, col=col2)
  lines(y=(bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time)/(1-bbfit[["p2"]]-bbfit[["p3"]])),
        x=toplot$date, type="l",col = "black")#, col=col3)
  str2=sprintf("%s: %s {%s, %s}",name2,format(round(bbfit[["s2"]],3),nsmall=3),format(round(myconf["s2","2.5 %"],3),nsmall=3),format(round(myconf["s2","97.5 %"],3),nsmall=3))
  str3=sprintf("%s: %s {%s, %s}",name3,format(round(bbfit[["s3"]],3),nsmall=3),format(round(myconf["s3","2.5 %"],3),nsmall=3),format(round(myconf["s3","97.5 %"],3),nsmall=3))
  text(x=toplot$date[1],y=500,str2,col = col2,pos=4, cex = 1)
  text(x=toplot$date[1],y=250,str3,col = col3,pos=4, cex = 1)
  axis(2, at=c(0.001,0.01,0.1,1,10,100,1000), labels=c(0.001,0.01,0.1,1,10,100,1000))
  #dev.off()
  
  #Bends suggest a changing selection over time (e.g., due to the impact of vaccinations
  #differentially impacting the variants). Sharper turns are more often due to NPI measures. 
}


