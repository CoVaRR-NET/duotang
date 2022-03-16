#Likelihood estimator of selection given two lineages
#Feb 2022
#Assumes an input file with {date, Pango.lineage, n}, 
#where n stands for the observed number of sequences of that lineage on that date.

#load libraries:
library(tidyverse)    #data wrangling and plotting
library(bbmle)

#set directory:
setwd("/Users/otto/Dropbox/COVID19/PHAC/OmicronSubtypesGISAID/Likelihood25Feb2022") #<- CHANGE! (MACs I think use \ ) to working directory

#load lineage data with {date, Pango.lineage, n}
mydata <-  read.csv("countbyday_British Columbia.csv")
mydata <-  read.csv("countbyday_Alberta.csv")
mydata <-  read.csv("countbyday_Ontario.csv")
mydata <-  read.csv("countbyday_CAN.csv")

#specify the two lineage names to be compared (the second one will typically be the newer one)
#(Choose one: BA.1 vs other is good to look at the need for breakpoints) 
name1<-"OTHER" #Can include a list here (first value is used as plot labels)
name2<-"BA.1" #Can include a list here (first value is used as plot labels)
#specify the colours for the variant lineages
col2 <- "#8B0000"

name1<-c("BA.1","BA.1.1") #Can include a list here (first value is used as plot labels)
name2<-"BA.2"  #Can include a list here (first value is used as plot labels)
#specify the colours for the variant lineages
col2 <- "#FA8072"

#Set a starting date and a final date:
#Note that the startdate shouldn't be too much before both alleles become common
#or rare migration events that die off could throw off the estimation procedure 
#(so that the parameter estimates account for the presence of those alleles long in the past).
#startdate<-"2021-11-15"
startdate<-"2021-12-15" #Using a later date with less sampling noise
lastdate<-max(mydata$day)

#filter data to after that starting date
data1 <- filter(mydata, mydata$Pango.lineage %in% name1)
data1 <- filter(data1, as.Date(data1$day) >= as.Date(startdate))
data2 <- filter(mydata, mydata$Pango.lineage %in% name2)
data2 <- filter(data2, as.Date(data2$day) >= as.Date(startdate))

#convert time to an integer counter for use in fitting, first using the last date as time 0:
data1$time = as.numeric(difftime(as.Date(data1$day), as.Date(lastdate), units = "days"))
data2$time = as.numeric(difftime(as.Date(data2$day), as.Date(lastdate), units = "days"))

#allow multiple Pango lineages to be combined if name1 or name2 includes a list, summing n
data1 <- as.data.frame(unique(data1 %>% group_by(time) %>% transmute(day=day,  n=sum(n), time=time)))
data2 <- as.data.frame(unique(data2 %>% group_by(time) %>% transmute(day=day,  n=sum(n), time=time)))
name1 <- name1[[1]]
name2 <- name2[[1]]
data1$Pango.lineage <- name1
data2$Pango.lineage <- name2

#join lists in a dataframe to plot proportions and represent time as a list of integers
timestart<-as.numeric(difftime(as.Date(startdate), as.Date(lastdate), units = "days"))
timeend<-as.numeric(difftime(as.Date(lastdate), as.Date(lastdate), units = "days"))
toplot <- data.frame(time = seq.int(timestart,timeend))
toplot$n1 <- data1$n[match(toplot$time,data1$time)]
toplot$n2 <- data2$n[match(toplot$time,data2$time)]
toplot[is.na(toplot)] = 0 #Any NA's refer to no variant of that type on a day, set to zero

#To aid in the ML search, we rescale time to be centered as close as possible
#to the midpoint (p=0.5), to make sure that the alleles are segregating at the reference date.
#If we set t=0 when p is near 0 or 1, then the likelihood surface is very flat.
refdate<-which(abs(toplot$n2/(toplot$n1+toplot$n2)-0.5)==min(abs(toplot$n2/(toplot$n1+toplot$n2)-0.5),na.rm=TRUE))
refdate<-refdate[[1]] #Just in case there is more than one matching point, the first is taken
timeend <- (timeend-timestart)-refdate
timestart <- -refdate
toplot$time <- seq.int(timestart,timeend)
data1$time <- data1$time + (timeend-timestart)-refdate
data2$time <- data2$time + (timeend-timestart)-refdate

#date converter
dateseq <- seq.Date(as.Date(startdate),as.Date(lastdate),"days")
dateconverter <- data.frame(time=toplot$time,date=as.Date(dateseq))

plot(y=toplot$n2/(toplot$n1+toplot$n2),x=toplot$time,xlab="Time",ylab="proportion",col=col2)

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
binfunc <- function(p,s){
  -(sum(data1$n*log((1-p)/((1-p)+p*exp(s*data1$time))))+
      sum(data2$n*log(p*exp(s*data2$time)/((1-p)+p*exp(s*data2$time)))))
}
startpar<-list(p=startp, s=0.2)
bbml<-mle2(binfunc, start = startpar)
bbml
#lnL
bbml.value<--bbml@min

#These confidence intervals are similar (I PREFER uniroot based on the profile likelihood procedure)
#confint(bbml) # based on inverting a spline fit to the profile 

#confint(bbml,method="quad") # based on the quadratic approximation at the maximum likelihood estimate

myconf<-confint(bbml,method="uniroot") # based on root-finding to find the exact point where the profile crosses the critical level
myconf

#Interesting way of profiling the likelihood
#bbprofile<-profile(bbml)
#plot(bbprofile)
#proffun(bbml)

################################
# Drawing random parameters for CI
################################
#We can draw random values for the parameters from the Hessian to determine the
#variation in {p,s} combinations consistent with the data using RandomFromHessianOrMCMC.

library(HelpersMG)

#We can also generate confidence intervals accounting for uncertainty in all parameters 
#by drawing from the covariance matrix estimated from the Hessian (the matrix of double derivatives
#describing the curvature of the likelihood surface near the ML peak).
bbfit<-c(p=bbml@details[["par"]][["p"]],s=bbml@details[["par"]][["s"]])
bbfit
bbhessian<-bbml@details[["hessian"]]
colnames(bbhessian) <- c("p","s")
rownames(bbhessian) <- c("p","s")
bbhessian

df <- RandomFromHessianOrMCMC(Hessian=(bbhessian), 
                        fitted.parameters=bbfit, 
                        method="Hessian",replicates=1000)$random

#Once we get the set of {p,s} values, we can run them through the s-shaped curve of selection
scurve <- function(p,s){
  (p*exp(s*toplot$time)/((1-p)+p*exp(s*toplot$time)))
}

#Generating a list of frequencies at each time point given each {p,s} combination
#NOTE - We could run more time points, if projections into the future were desired just by 
#extending toplot$time
setofcurves <- t(mapply(scurve,df[,1],df[,2]))

#95% innerquantiles
lowercurve <- c()
uppercurve <- c()
for (tt in 1:length(toplot$time))  {
  lower<-quantile(setofcurves[,tt],0.025)
  upper<-quantile(setofcurves[,tt],0.975)
  lowercurve<-append(lowercurve,lower)
  uppercurve<-append(uppercurve,upper)
}

#A crude graph with 95% quantiles based on the Hessian draws.
#It would be better to give a sense of the amount of data in each point and fix the date axis.
plot(y=uppercurve,x=toplot$time,type="l",xlab="Time",ylab="proportion",ylim=c(0,1))
polygon(c(toplot$time, rev(toplot$time)), c(lowercurve, rev(uppercurve)),col = col2)
points(y=toplot$n2/(toplot$n1+toplot$n2),x=toplot$time,pch=19, cex = 0.5)
lines(y=(bbfit[["p"]]*exp(bbfit[["s"]]*toplot$time)/((1-bbfit[["p"]])+bbfit[["p"]]*exp(bbfit[["s"]]*toplot$time))),
      x=toplot$time,type="l")
str2=sprintf("%s: %s {%s, %s}",name2,format(round(bbfit[["s"]],3),nsmall=3),format(round(myconf[2],3),nsmall=3),format(round(myconf[4],3),nsmall=3))
text(x=timestart,y=0.95,str2,col = col2,pos=4, cex = 0.75)

################################
# Looking for a breakpoint
################################
#Visually, there is a breakpoint on a logit curve whenever selection changes in strength
#Specifically, if we plot p/(1-p) on a log scale, that should be proportional to s*time
#Note that migrants that fail to take off can also cause the appearance of low frequencies
#persisting over time (if you see this, better to use a later starting time point
#to ensure that establishment has occurred.

plot(y=bbfit[["p"]]*exp(bbfit[["s"]]*toplot$time)/(1-bbfit[["p"]]),
     x=toplot$time,type="l",log="y",ylim=c(0.001,1000),xlab="Time",ylab="logit")
points(y=toplot$n2/toplot$n1,x=toplot$time,pch=19, cex = 0.5,col=col2)
str2=sprintf("%s: %s {%s, %s}",name2,format(round(bbfit[["s"]],3),nsmall=3),format(round(myconf[2],3),nsmall=3),format(round(myconf[4],3),nsmall=3))
text(x=timestart,y=500,str2,col = col2,pos=4, cex = 0.75)

#Based on the plot for BA.1 vs Other, we'll use the following breakdate (but this should be optimized?)
breakdate<-"2021-12-24"

breakfunc <- function(p,s1,s2){
  early1 <- filter(data1, as.Date(data1$day) < as.Date(breakdate))
  early2 <- filter(data2, as.Date(data2$day) < as.Date(breakdate))
  late1 <- filter(data1, as.Date(data1$day) >= as.Date(breakdate))
  late2 <- filter(data2, as.Date(data2$day) >= as.Date(breakdate))
  -(sum(early1$n*log((1-p)/((1-p)+p*exp(s1*early1$time))))+
      sum(early2$n*log(p*exp(s1*early2$time)/((1-p)+p*exp(s1*early2$time))))+
      sum(late1$n*log((1-p)/((1-p)+p*exp(s2*late1$time))))+
      sum(late2$n*log(p*exp(s2*late2$time)/((1-p)+p*exp(s2*late2$time)))))
}

#As a check, we should get the same lnL if we set the selection coefficients and p
#to the same value as in the maximum likelihood point above (checks out ok)
breakfunc(p=bbfit[["p"]],s1=bbfit[["s"]],s2=bbfit[["s"]])

#Starting point (had trouble sending dates through as starting parameters, 
#so trybreak gives the element in data1$day to use as the breakpoint)
#trybreak <- which(data1$day == "2021-12-24")

startpar <- list(p=startp,s1=0.2,s2=0.05)
bbbreak<-mle2(breakfunc, start = startpar)
bbbreak
bbbreakfit<-c(p=bbbreak@details[["par"]][["p"]],s1=bbbreak@details[["par"]][["s1"]],s2=bbbreak@details[["par"]][["s2"]])
bbbreakfit

#lnL
bbbreak.value <- -bbbreak@min
bbbreak.value-bbml.value
#Only breakpoints significantly increasing the likelihood should be accepted
#(Here tested with one degree of extra freedom for the extra s value [check])
bbbreak.value-bbml.value>qchisq(0.95, 1)/2

#Continue only if the above breakpoint is significant
#Confidence intervals are similar (go with uniroot?)
myconfbreak<-confint(bbbreak,method="uniroot") # based on root-finding to find the exact point where the profile crosses the critical level
myconfbreak

#Plot with break points in selection
#TO DO (if used): Fix x axis range for the first and second line to go up to the breakdate using dateconverter
#TO FIX: Have y-axis read 0.001,0.01,0.1,1,10,100,1000 ?
plot(y=bbbreakfit[["p"]]*exp(bbbreakfit[["s1"]]*toplot$time)/(1-bbbreakfit[["p"]]),
     x=toplot$time,type="l",log="y",ylim=c(0.001,1000),xlab="Time",ylab="logit")
lines(y=bbbreakfit[["p"]]*exp(bbbreakfit[["s2"]]*toplot$time)/(1-bbbreakfit[["p"]]),
      x=toplot$time,type="l",log="y",lty = "dashed")
points(y=toplot$n2/toplot$n1,x=toplot$time,pch=19, cex = 0.5,log="y",col=col2)
str2=sprintf("Early %s: %s {%s, %s}",name2,format(round(bbbreakfit[["s1"]],3),nsmall=3),format(round(myconfbreak[2],3),nsmall=3),format(round(myconfbreak[5],3),nsmall=3))
text(x=timestart,y=500,str2,col = col2,pos=4, cex = 0.75)
str3=sprintf("Late %s: %s {%s, %s}",name2,format(round(bbbreakfit[["s2"]],3),nsmall=3),format(round(myconfbreak[3],3),nsmall=3),format(round(myconfbreak[6],3),nsmall=3))
text(x=timestart,y=200,str3,col = col2,pos=4, cex = 0.75)

#ALSO TO DO (if used): Use Jeffrey's Intervals on the logit plot to better describe fit to the data
#Jeffrey's interval for p at any given time is based on the Beta Distribution 
#(this is basically the Bayesian confidence interval with an uninformative prior).
#This helps to see which dots have substantial information and which don't.
#For each dot, x is the number of variant type 1 and y is the number of variant type 2 on a given day.

#MATHEMATICA CODE; see R code here: https://www.rdocumentation.org/packages/DescTools/versions/0.99.44/topics/BinomCI:
#upper[x_, y_] := 
#  p /. Flatten[
#    Solve[CDF[BetaDistribution[x + 1/2, (x + y) - x + 1/2], p] == 0.975, p]];
#lower[x_, y_] := 
#  p /. Flatten[
#    Solve[CDF[BetaDistribution[x + 1/2, (x + y) - x + 1/2], p] == 0.025, p]];