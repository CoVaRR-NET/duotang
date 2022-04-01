suppressMessages(suppressWarnings(library(tidytree)))
suppressMessages(suppressWarnings(library(bbmle)))
suppressMessages(suppressWarnings(library(HelpersMG)))
suppressMessages(suppressWarnings(library(dplyr)))

#Province weight table, based on Q4 2021, might need to be updated regularly
prov_weight <- data.frame(province = character(),mul = numeric())
prov_weight[nrow(prov_weight)+1, ]=list("Newfoundland_and_Labrador",         "0.015")
prov_weight[nrow(prov_weight)+1, ]=list("Quebec",         "0.256")
prov_weight[nrow(prov_weight)+1, ]=list("Manitoba",         "0.041")
prov_weight[nrow(prov_weight)+1, ]=list("Saskatchewan",         "0.035")
prov_weight[nrow(prov_weight)+1, ]=list("Nova_Scotia",   "0.03")
prov_weight[nrow(prov_weight)+1, ]=list("Ontario",   "0.443")
prov_weight[nrow(prov_weight)+1, ]=list("New_Brunswick",   "0.024")
prov_weight[nrow(prov_weight)+1, ]=list("British_Columbia",   "0.156")

prov_weight$mul<-as.numeric(prov_weight$mul)



plot_selection_estimator4 <- function(prov,startdate,name1,name2,name3,col2,col3) {
  mydata=metaCANall %>% filter(grepl("BA.", Pango_lineage), province != "Alberta", !is.na(Collection_date), Collection_date >= startdate) %>% group_by(Collection_date,province) %>% count(Pango_lineage)

  #Set the final date:
  lastdate<-max(mydata$Collection_date)
  
  #convert time to an integer counter for use in fitting, first using the last date as time 0:
  mydata$time = as.numeric(difftime(mydata$Collection_date, lastdate, units = "days"))
  
  #filter data to after that starting date
  data1 <- filter(mydata, Pango_lineage %in% name1)
  data2 <- filter(mydata, Pango_lineage %in% name2)
  data3 <- filter(mydata, Pango_lineage %in% name3)
  
  #allow multiple Pango lineages to be combined if name1 or name2 includes a list, summing n
  #data1 <- as.data.frame(unique(data1 %>% group_by(time) %>% transmute(day=Collection_date,  n=sum(n), time=time)))
  #data2 <- as.data.frame(unique(data2 %>% group_by(time) %>% transmute(day=Collection_date,  n=sum(n), time=time)))
  #data3 <- as.data.frame(unique(data3 %>% group_by(time) %>% transmute(day=Collection_date,  n=sum(n), time=time)))
  name1 <- name1[[1]]
  name2 <- name2[[1]]
  name3 <- name3[[1]]
  data1$Pango_lineage <- name1
  data2$Pango_lineage <- name2
  data3$Pango_lineage <- name3
  
  data1$n_adj<-data1$n
  data2$n_adj<-data2$n
  data3$n_adj<-data3$n
  
  data1a<-left_join(data1,prov_weight) %>% mutate_at(("n_adj"),funs(.*mul))#make adjusted n value by multiplying by population fraction, provinces separate
  data1b<- data1a %>% group_by(Collection_date,time, province) %>% summarize(n_adj=sum(n_adj),n=sum(n))#
  data1c<- data1b %>% group_by(Collection_date,time) %>% summarize(n_adj=sum(n_adj),n=sum(n))#summarize across provinces

  data2a<-left_join(data2,prov_weight) %>% mutate_at(("n_adj"),funs(.*mul))
  data2b<- data2a %>% group_by(Collection_date,time,province) %>% summarize(n_adj=sum(n_adj),n=sum(n))
  data2c<- data2b %>% group_by(Collection_date,time) %>% summarize(n_adj=sum(n_adj),n=sum(n))
  
  data3a<-left_join(data3,prov_weight) %>% mutate_at(("n_adj"),funs(.*mul))
  data3b<- data3a %>% group_by(Collection_date,time,province) %>% summarize(n_adj=sum(n_adj),n=sum(n))
  data3c<- data3b %>% group_by(Collection_date,time) %>% summarize(n_adj=sum(n_adj),n=sum(n))
     
  #join lists in a dataframe to plot proportions and represent time as a list of integers
  timestart<-as.numeric(difftime(startdate, lastdate, units = "days"))
  timeend<-as.numeric(difftime(lastdate, lastdate, units = "days"))
  toplot <- data.frame(time = seq.int(timestart,timeend))
  toplot$n1_adj <- data1c$n_adj[match(toplot$time,data1c$time)]
  toplot$n1 <- data1c$n[match(toplot$time,data1c$time)]
  toplot$n2_adj <- data2c$n_adj[match(toplot$time,data2c$time)]
  toplot$n2 <- data2c$n[match(toplot$time,data2c$time)]
  toplot$n3_adj <- data3c$n_adj[match(toplot$time,data3c$time)]
  toplot$n <- data3c$n[match(toplot$time,data3c$time)]
  toplot[is.na(toplot)] = 0 #Any NA's refer to no variant of that type on a day, set to zero
  
  
  #To aid in the ML search, we rescale time to be centered as close as possible
  #to the midpoint for the second variable (p=0.5), to make sure that the alleles 
  #are segregating at the reference date.
  #If we set t=0 when p is near 0 or 1, then the likelihood surface is very flat.
  v=(toplot$n1*toplot$n2*toplot$n3)/(toplot$n1+toplot$n2+toplot$n3)^3
  refdate<-which(v==max(v,na.rm=TRUE))
  refdate<-refdate[[1]] #Just in case there is more than one matching point, the first is taken
  timeend <- (timeend-timestart)-refdate
  timestart <- -refdate
  toplot$time <- seq.int(timestart,timeend)
  data1$time <- data1$time + (timeend-timestart)-refdate
  data2$time <- data2$time + (timeend-timestart)-refdate
  data3$time <- data3$time + (timeend-timestart)-refdate
  

  data1c$time <- data1c$time + (timeend-timestart)-refdate
  data2c$time <- data2c$time + (timeend-timestart)-refdate
  data3c$time <- data3c$time + (timeend-timestart)-refdate
  
  
  
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
  # Province Data sets for confidence intervals
  ##############################
  data1_NF<-subset(data1b,province=="Newfoundland_and_Labrador")
  data2_NF<-subset(data2b,province=="Newfoundland_and_Labrador") 
  data3_NF<-subset(data3b,province=="Newfoundland_and_Labrador")
  data1_QC<-subset(data1b,province=="Quebec")
  data2_QC<-subset(data2b,province=="Quebec") 
  data3_QC<-subset(data3b,province=="Quebec")  
  data1_ON<-subset(data1b,province=="Ontario")
  data2_ON<-subset(data2b,province=="Ontario") 
  data3_ON<-subset(data3b,province=="Ontario")
  data1_MN<-subset(data1b,province=="Manitoba")
  data2_MN<-subset(data2b,province=="Manitoba") 
  data3_MN<-subset(data3b,province=="Manitoba")
  data1_SK<-subset(data1b,province=="Saskatchewan")
  data2_SK<-subset(data2b,province=="Saskatchewan") 
  data3_SK<-subset(data3b,province=="Saskatchewan")
  data1_NS<-subset(data1b,province=="Nova_Scotia")
  data2_NS<-subset(data2b,province=="Nova_Scotia") 
  data3_NS<-subset(data3b,province=="Nova_Scotia")
  data1_NB<-subset(data1b,province=="New_Brunswick")
  data2_NB<-subset(data2b,province=="New_Brunswick") 
  data3_NB<-subset(data3b,province=="New_Brunswick")
  data1_BC<-subset(data1b,province=="British_Columbia")
  data2_BC<-subset(data2b,province=="British_Columbia") 
  data3_BC<-subset(data3b,province=="British_Columbia")
  
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
    -(sum(data1c$n_adj*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1c$time)+p3*exp(s3*data1c$time))))+
        sum(data2c$n_adj*log(p2*exp(s2*data2c$time)/((1-p2-p3)+p2*exp(s2*data2c$time)+p3*exp(s3*data2c$time))))+
        sum(data3c$n_adj*log(p3*exp(s3*data3c$time)/((1-p2-p3)+p2*exp(s2*data3c$time)+p3*exp(s3*data3c$time)))))
  }#function for the whole data set
  
    trifunc_NF <- function(p2,p3,s2,s3){
    -(sum(data1_NF$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_NF$time)+p3*exp(s3*data1_NF$time))))+
        sum(data2_NF$n*log(p2*exp(s2*data2_NF$time)/((1-p2-p3)+p2*exp(s2*data2_NF$time)+p3*exp(s3*data2_NF$time))))+
        sum(data3_NF$n*log(p3*exp(s3*data3_NF$time)/((1-p2-p3)+p2*exp(s2*data3_NF$time)+p3*exp(s3*data3_NF$time)))))
  }
  
  trifunc_QC <- function(p2,p3,s2,s3){
    -(sum(data1_QC$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_QC$time)+p3*exp(s3*data1_QC$time))))+
        sum(data2_QC$n*log(p2*exp(s2*data2_QC$time)/((1-p2-p3)+p2*exp(s2*data2_QC$time)+p3*exp(s3*data2_QC$time))))+
        sum(data3_QC$n*log(p3*exp(s3*data3_QC$time)/((1-p2-p3)+p2*exp(s2*data3_QC$time)+p3*exp(s3*data3_QC$time)))))
  }
  
  trifunc_ON <- function(p2,p3,s2,s3){
    -(sum(data1_ON$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_ON$time)+p3*exp(s3*data1_ON$time))))+
        sum(data2_ON$n*log(p2*exp(s2*data2_ON$time)/((1-p2-p3)+p2*exp(s2*data2_ON$time)+p3*exp(s3*data2_ON$time))))+
        sum(data3_ON$n*log(p3*exp(s3*data3_ON$time)/((1-p2-p3)+p2*exp(s2*data3_ON$time)+p3*exp(s3*data3_ON$time)))))
  }
  
  trifunc_MN <- function(p2,p3,s2,s3){
    -(sum(data1_MN$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_MN$time)+p3*exp(s3*data1_MN$time))))+
        sum(data2_MN$n*log(p2*exp(s2*data2_MN$time)/((1-p2-p3)+p2*exp(s2*data2_MN$time)+p3*exp(s3*data2_MN$time))))+
        sum(data3_MN$n*log(p3*exp(s3*data3_MN$time)/((1-p2-p3)+p2*exp(s2*data3_MN$time)+p3*exp(s3*data3_MN$time)))))
  }
  
  trifunc_NS <- function(p2,p3,s2,s3){
    -(sum(data1_NS$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_NS$time)+p3*exp(s3*data1_NS$time))))+
        sum(data2_NS$n*log(p2*exp(s2*data2_NS$time)/((1-p2-p3)+p2*exp(s2*data2_NS$time)+p3*exp(s3*data2_NS$time))))+
        sum(data3_NS$n*log(p3*exp(s3*data3_NS$time)/((1-p2-p3)+p2*exp(s2*data3_NS$time)+p3*exp(s3*data3_NS$time)))))
  }
  
  trifunc_SK <- function(p2,p3,s2,s3){
    -(sum(data1_SK$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_SK$time)+p3*exp(s3*data1_SK$time))))+
        sum(data2_SK$n*log(p2*exp(s2*data2_SK$time)/((1-p2-p3)+p2*exp(s2*data2_SK$time)+p3*exp(s3*data2_SK$time))))+
        sum(data3_SK$n*log(p3*exp(s3*data3_SK$time)/((1-p2-p3)+p2*exp(s2*data3_SK$time)+p3*exp(s3*data3_SK$time)))))
  }
  
  trifunc_NB <- function(p2,p3,s2,s3){
    -(sum(data1_NB$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_NB$time)+p3*exp(s3*data1_NB$time))))+
        sum(data2_NB$n*log(p2*exp(s2*data2_NB$time)/((1-p2-p3)+p2*exp(s2*data2_NB$time)+p3*exp(s3*data2_NB$time))))+
        sum(data3_NB$n*log(p3*exp(s3*data3_NB$time)/((1-p2-p3)+p2*exp(s2*data3_NB$time)+p3*exp(s3*data3_NB$time)))))
  }
  
  trifunc_BC <- function(p2,p3,s2,s3){
    -(sum(data1_BC$n*log((1-p2-p3)/((1-p2-p3)+p2*exp(s2*data1_BC$time)+p3*exp(s3*data1_BC$time))))+
        sum(data2_BC$n*log(p2*exp(s2*data2_BC$time)/((1-p2-p3)+p2*exp(s2*data2_BC$time)+p3*exp(s3*data2_BC$time))))+
        sum(data3_BC$n*log(p3*exp(s3*data3_BC$time)/((1-p2-p3)+p2*exp(s2*data3_BC$time)+p3*exp(s3*data3_BC$time)))))
  }
  
  startpar<-list(p2=startp, p3=0.05, s2=0.1, s3=0.1)
  bbml<-mle2(trifunc, start = startpar)
  bbml_NF<-mle2(trifunc_NF, start = startpar)
  bbml_QC<-mle2(trifunc_QC, start = startpar)
  bbml_ON<-mle2(trifunc_ON, start = startpar)  
  bbml_MN<-mle2(trifunc_MN, start = startpar)  
  bbml_NS<-mle2(trifunc_NS, start = startpar)  
  bbml_SK<-mle2(trifunc_SK, start = startpar)
  bbml_NB<-mle2(trifunc_NB, start = startpar)
  bbml_BC<-mle2(trifunc_BC, start = startpar)
  
  bbml
  bbml_NF
  bbml_QC
  bbml_ON
  bbml_MN
  bbml_NS
  bbml_SK
  bbml_NB
  bbml_BC
  
  #lnL
  bbml.value<--bbml@min
  bbml_NF.value<--bbml_NF@min
  bbml_QC.value<--bbml_QC@min
  bbml_ON.value<--bbml_ON@min
  bbml_MN.value<--bbml_MN@min
  bbml_NS.value<--bbml_NS@min
  bbml_SK.value<--bbml_SK@min
  bbml_NB.value<--bbml_NB@min
  bbml_BC.value<--bbml_BC@min
  
  
  #These confidence intervals are similar (I PREFER uniroot based on the profile likelihood procedure)
  #confint(bbml) # based on inverting a spline fit to the profile 
  
  myconf<-confint(bbml,method="quad") # based on the quadratic approximation at the maximum likelihood estimate
  myconf_NF<-confint(bbml_NF,method="quad")
  myconf_QC<-confint(bbml_QC,method="quad")
  myconf_ON<-confint(bbml_ON,method="quad")
  myconf_MN<-confint(bbml_MN,method="quad")
  myconf_NS<-confint(bbml_NS,method="quad")
  myconf_SK<-confint(bbml_SK,method="quad")
  myconf_NB<-confint(bbml_NB,method="quad")
  myconf_BC<-confint(bbml_BC,method="quad")
  
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
  
  bbfit_NF<-c(p2=bbml_NF@details[["par"]][["p2"]],p3=bbml_NF@details[["par"]][["p3"]],
           s2=bbml_NF@details[["par"]][["s2"]],s3=bbml_NF@details[["par"]][["s3"]])
  bbfit_QC<-c(p2=bbml_QC@details[["par"]][["p2"]],p3=bbml_QC@details[["par"]][["p3"]],
              s2=bbml_QC@details[["par"]][["s2"]],s3=bbml_QC@details[["par"]][["s3"]])
  bbfit_ON<-c(p2=bbml_ON@details[["par"]][["p2"]],p3=bbml_ON@details[["par"]][["p3"]],
              s2=bbml_ON@details[["par"]][["s2"]],s3=bbml_ON@details[["par"]][["s3"]])
  bbfit_MN<-c(p2=bbml_MN@details[["par"]][["p2"]],p3=bbml_MN@details[["par"]][["p3"]],
              s2=bbml_MN@details[["par"]][["s2"]],s3=bbml_MN@details[["par"]][["s3"]])
  bbfit_NS<-c(p2=bbml_NS@details[["par"]][["p2"]],p3=bbml_NS@details[["par"]][["p3"]],
              s2=bbml_NS@details[["par"]][["s2"]],s3=bbml_NS@details[["par"]][["s3"]])
  bbfit_SK<-c(p2=bbml_SK@details[["par"]][["p2"]],p3=bbml_SK@details[["par"]][["p3"]],
              s2=bbml_SK@details[["par"]][["s2"]],s3=bbml_SK@details[["par"]][["s3"]])
  bbfit_NB<-c(p2=bbml_NB@details[["par"]][["p2"]],p3=bbml_NB@details[["par"]][["p3"]],
              s2=bbml_NB@details[["par"]][["s2"]],s3=bbml_NB@details[["par"]][["s3"]])
  bbfit_BC<-c(p2=bbml_BC@details[["par"]][["p2"]],p3=bbml_BC@details[["par"]][["p3"]],
              s2=bbml_BC@details[["par"]][["s2"]],s3=bbml_BC@details[["par"]][["s3"]])
  
   bbfit_NF
   bbfit_QC   
   bbfit_ON
   bbfit_MN
   bbfit_NS
   bbfit_SK
   bbfit_NB
   bbfit_BC
   
  bbhessian_NF<-bbml_NF@details[["hessian"]]
  colnames(bbhessian_NF) <- c("p2","p3","s2","s3")
  rownames(bbhessian_NF) <- c("p2","p3","s2","s3")
  bbhessian_NF
 
  bbhessian_QC<-bbml_QC@details[["hessian"]]
  colnames(bbhessian_QC) <- c("p2","p3","s2","s3")
  rownames(bbhessian_QC) <- c("p2","p3","s2","s3")
  bbhessian_QC
  
  bbhessian_ON<-bbml_ON@details[["hessian"]]
  colnames(bbhessian_ON) <- c("p2","p3","s2","s3")
  rownames(bbhessian_ON) <- c("p2","p3","s2","s3")
  bbhessian_ON
  
  bbhessian_MN<-bbml_MN@details[["hessian"]]
  colnames(bbhessian_MN) <- c("p2","p3","s2","s3")
  rownames(bbhessian_MN) <- c("p2","p3","s2","s3")
  bbhessian_MN
  
  bbhessian_NS<-bbml_NS@details[["hessian"]]
  colnames(bbhessian_NS) <- c("p2","p3","s2","s3")
  rownames(bbhessian_NS) <- c("p2","p3","s2","s3")
  bbhessian_NS
  
  bbhessian_SK<-bbml_SK@details[["hessian"]]
  colnames(bbhessian_SK) <- c("p2","p3","s2","s3")
  rownames(bbhessian_SK) <- c("p2","p3","s2","s3")
  bbhessian_SK
  
  bbhessian_NB<-bbml_NB@details[["hessian"]]
  colnames(bbhessian_NB) <- c("p2","p3","s2","s3")
  rownames(bbhessian_NB) <- c("p2","p3","s2","s3")
  bbhessian_NB
  
  bbhessian_BC<-bbml_BC@details[["hessian"]]
  colnames(bbhessian_BC) <- c("p2","p3","s2","s3")
  rownames(bbhessian_BC) <- c("p2","p3","s2","s3")
  bbhessian_BC
  
 
  df_NF <- RandomFromHessianOrMCMC(Hessian=(bbhessian_NF), 
                                fitted.parameters=bbfit_NF, 
                                method="Hessian",replicates=1000,silent = TRUE)$random
 
  df_QC <- RandomFromHessianOrMCMC(Hessian=(bbhessian_QC), 
                                   fitted.parameters=bbfit_QC, 
                                   method="Hessian",replicates=1000,silent = TRUE)$random
  
  df_ON <- RandomFromHessianOrMCMC(Hessian=(bbhessian_ON), 
                                   fitted.parameters=bbfit_ON, 
                                   method="Hessian",replicates=1000,silent = TRUE)$random
  
  df_MN <- RandomFromHessianOrMCMC(Hessian=(bbhessian_MN), 
                                   fitted.parameters=bbfit_MN, 
                                   method="Hessian",replicates=1000,silent = TRUE)$random
  
  df_SK <- RandomFromHessianOrMCMC(Hessian=(bbhessian_SK), 
                                   fitted.parameters=bbfit_SK, 
                                   method="Hessian",replicates=1000,silent = TRUE)$random
  
  df_NS <- RandomFromHessianOrMCMC(Hessian=(bbhessian_NS), 
                                   fitted.parameters=bbfit_NS, 
                                   method="Hessian",replicates=1000,silent = TRUE)$random
  
  df_NB <- RandomFromHessianOrMCMC(Hessian=(bbhessian_NB), 
                                   fitted.parameters=bbfit_NB, 
                                   method="Hessian",replicates=1000,silent = TRUE)$random
  
  df_BC <- RandomFromHessianOrMCMC(Hessian=(bbhessian_BC), 
                                   fitted.parameters=bbfit_BC, 
                                   method="Hessian",replicates=1000,silent = TRUE)$random
  
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
  setofcurves2_NF <- t(mapply(scurve1,df_NF[,1],df_NF[,2],df_NF[,3],df_NF[,4]))
  setofcurves3_NF <- t(mapply(scurve2,df_NF[,1],df_NF[,2],df_NF[,3],df_NF[,4]))

  setofcurves2_QC <- t(mapply(scurve1,df_QC[,1],df_QC[,2],df_QC[,3],df_QC[,4]))
  setofcurves3_QC <- t(mapply(scurve2,df_QC[,1],df_QC[,2],df_QC[,3],df_QC[,4]))
  
  setofcurves2_ON <- t(mapply(scurve1,df_ON[,1],df_ON[,2],df_ON[,3],df_ON[,4]))
  setofcurves3_ON <- t(mapply(scurve2,df_ON[,1],df_ON[,2],df_ON[,3],df_ON[,4]))
  
  setofcurves2_MN <- t(mapply(scurve1,df_MN[,1],df_MN[,2],df_MN[,3],df_MN[,4]))
  setofcurves3_MN <- t(mapply(scurve2,df_MN[,1],df_MN[,2],df_MN[,3],df_MN[,4]))
  
  setofcurves2_SK <- t(mapply(scurve1,df_SK[,1],df_SK[,2],df_SK[,3],df_SK[,4]))
  setofcurves3_SK <- t(mapply(scurve2,df_SK[,1],df_SK[,2],df_SK[,3],df_SK[,4]))
  
  setofcurves2_NS <- t(mapply(scurve1,df_NS[,1],df_NS[,2],df_NS[,3],df_NS[,4]))
  setofcurves3_NS <- t(mapply(scurve2,df_NS[,1],df_NS[,2],df_NS[,3],df_NS[,4]))
  
  setofcurves2_NB <- t(mapply(scurve1,df_NB[,1],df_NB[,2],df_NB[,3],df_NB[,4]))
  setofcurves3_NB <- t(mapply(scurve2,df_NB[,1],df_NB[,2],df_NB[,3],df_NB[,4]))
  
  setofcurves2_BC <- t(mapply(scurve1,df_BC[,1],df_BC[,2],df_BC[,3],df_BC[,4]))
  setofcurves3_BC <- t(mapply(scurve2,df_BC[,1],df_BC[,2],df_BC[,3],df_BC[,4]))
    
  #95% innerquantiles
  lowercurve1_NF <- c()
  uppercurve1_NF <- c()
  lowercurve2_NF <- c()
  uppercurve2_NF <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_NF<-quantile(setofcurves2_NF[,tt],0.025)
    upper1_NF<-quantile(setofcurves2_NF[,tt],0.975)
    lowercurve1_NF<-append(lowercurve1_NF,lower1_NF)
    uppercurve1_NF<-append(uppercurve1_NF,upper1_NF)
    
    lower2_NF<-quantile(setofcurves3_NF[,tt],0.025)
    upper2_NF<-quantile(setofcurves3_NF[,tt],0.975)
    lowercurve2_NF<-append(lowercurve2_NF,lower2_NF)
    uppercurve2_NF<-append(uppercurve2_NF,upper2_NF)
  }
  
  lowercurve1_QC <- c()
  uppercurve1_QC <- c()
  lowercurve2_QC <- c()
  uppercurve2_QC <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_QC<-quantile(setofcurves2_QC[,tt],0.025)
    upper1_QC<-quantile(setofcurves2_QC[,tt],0.975)
    lowercurve1_QC<-append(lowercurve1_QC,lower1_QC)
    uppercurve1_QC<-append(uppercurve1_QC,upper1_QC)
    
    lower2_QC<-quantile(setofcurves3_QC[,tt],0.025)
    upper2_QC<-quantile(setofcurves3_QC[,tt],0.975)
    lowercurve2_QC<-append(lowercurve2_QC,lower2_QC)
    uppercurve2_QC<-append(uppercurve2_QC,upper2_QC)
  }
  
  lowercurve1_ON <- c()
  uppercurve1_ON <- c()
  lowercurve2_ON <- c()
  uppercurve2_ON <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_ON<-quantile(setofcurves2_ON[,tt],0.025)
    upper1_ON<-quantile(setofcurves2_ON[,tt],0.975)
    lowercurve1_ON<-append(lowercurve1_ON,lower1_ON)
    uppercurve1_ON<-append(uppercurve1_ON,upper1_ON)
    
    lower2_ON<-quantile(setofcurves3_ON[,tt],0.025)
    upper2_ON<-quantile(setofcurves3_ON[,tt],0.975)
    lowercurve2_ON<-append(lowercurve2_ON,lower2_ON)
    uppercurve2_ON<-append(uppercurve2_ON,upper2_ON)
  }
  
  lowercurve1_MN <- c()
  uppercurve1_MN <- c()
  lowercurve2_MN <- c()
  uppercurve2_MN <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_MN<-quantile(setofcurves2_MN[,tt],0.025)
    upper1_MN<-quantile(setofcurves2_MN[,tt],0.975)
    lowercurve1_MN<-append(lowercurve1_MN,lower1_MN)
    uppercurve1_MN<-append(uppercurve1_MN,upper1_MN)
    
    lower2_MN<-quantile(setofcurves3_MN[,tt],0.025)
    upper2_MN<-quantile(setofcurves3_MN[,tt],0.975)
    lowercurve2_MN<-append(lowercurve2_MN,lower2_MN)
    uppercurve2_MN<-append(uppercurve2_MN,upper2_MN)
  }
  
  lowercurve1_SK <- c()
  uppercurve1_SK <- c()
  lowercurve2_SK <- c()
  uppercurve2_SK <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_SK<-quantile(setofcurves2_SK[,tt],0.025)
    upper1_SK<-quantile(setofcurves2_SK[,tt],0.975)
    lowercurve1_SK<-append(lowercurve1_SK,lower1_SK)
    uppercurve1_SK<-append(uppercurve1_SK,upper1_SK)
    
    lower2_SK<-quantile(setofcurves3_SK[,tt],0.025)
    upper2_SK<-quantile(setofcurves3_SK[,tt],0.975)
    lowercurve2_SK<-append(lowercurve2_SK,lower2_SK)
    uppercurve2_SK<-append(uppercurve2_SK,upper2_SK)
  }
  
  lowercurve1_NS <- c()
  uppercurve1_NS <- c()
  lowercurve2_NS <- c()
  uppercurve2_NS <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_NS<-quantile(setofcurves2_NS[,tt],0.025)
    upper1_NS<-quantile(setofcurves2_NS[,tt],0.975)
    lowercurve1_NS<-append(lowercurve1_NS,lower1_NS)
    uppercurve1_NS<-append(uppercurve1_NS,upper1_NS)
    
    lower2_NS<-quantile(setofcurves3_NS[,tt],0.025)
    upper2_NS<-quantile(setofcurves3_NS[,tt],0.975)
    lowercurve2_NS<-append(lowercurve2_NS,lower2_NS)
    uppercurve2_NS<-append(uppercurve2_NS,upper2_NS)
  }
  
  lowercurve1_NB <- c()
  uppercurve1_NB <- c()
  lowercurve2_NB <- c()
  uppercurve2_NB <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_NB<-quantile(setofcurves2_NB[,tt],0.025)
    upper1_NB<-quantile(setofcurves2_NB[,tt],0.975)
    lowercurve1_NB<-append(lowercurve1_NB,lower1_NB)
    uppercurve1_NB<-append(uppercurve1_NB,upper1_NB)
    
    lower2_NB<-quantile(setofcurves3_NB[,tt],0.025)
    upper2_NB<-quantile(setofcurves3_NB[,tt],0.975)
    lowercurve2_NB<-append(lowercurve2_NB,lower2_NB)
    uppercurve2_NB<-append(uppercurve2_NB,upper2_NB)
  }
  
  lowercurve1_BC <- c()
  uppercurve1_BC <- c()
  lowercurve2_BC <- c()
  uppercurve2_BC <- c()
  for (tt in 1:length(toplot$time))  {
    lower1_BC<-quantile(setofcurves2_BC[,tt],0.025)
    upper1_BC<-quantile(setofcurves2_BC[,tt],0.975)
    lowercurve1_BC<-append(lowercurve1_BC,lower1_BC)
    uppercurve1_BC<-append(uppercurve1_BC,upper1_BC)
    
    lower2_BC<-quantile(setofcurves3_BC[,tt],0.025)
    upper2_BC<-quantile(setofcurves3_BC[,tt],0.975)
    lowercurve2_BC<-append(lowercurve2_BC,lower2_BC)
    uppercurve2_BC<-append(uppercurve2_BC,upper2_BC)
  }
  
  #weighted CIs
  lowercurve1_weighted<-(lowercurve1_BC*0.156)+(lowercurve1_MN*0.041)+(lowercurve1_NB*0.024)+(lowercurve1_NF*0.015)+(lowercurve1_NS*0.03)+(lowercurve1_ON*0.443)+(lowercurve1_QC*0.256)+(lowercurve1_SK*0.035)
  lowercurve2_weighted<-(lowercurve2_BC*0.156)+(lowercurve2_MN*0.041)+(lowercurve2_NB*0.024)+(lowercurve2_NF*0.015)+(lowercurve2_NS*0.03)+(lowercurve2_ON*0.443)+(lowercurve2_QC*0.256)+(lowercurve2_SK*0.035)
  uppercurve1_weighted<-(uppercurve1_BC*0.156)+(uppercurve1_MN*0.041)+(uppercurve1_NB*0.024)+(uppercurve1_NF*0.015)+(uppercurve1_NS*0.03)+(uppercurve1_ON*0.443)+(uppercurve1_QC*0.256)+(uppercurve1_SK*0.035)
  uppercurve2_weighted<-(uppercurve2_BC*0.156)+(uppercurve2_MN*0.041)+(uppercurve2_NB*0.024)+(uppercurve2_NF*0.015)+(uppercurve2_NS*0.03)+(uppercurve2_ON*0.443)+(uppercurve2_QC*0.256)+(uppercurve2_SK*0.035)
  
  #add date column
  toplot$date <- dateconverter$date
  
  #A graph with 95% quantiles based on the Hessian draws.
  #png(file=paste0("curves_",i,".png"))
  plot(y=uppercurve1_weighted,x=toplot$date,type="l",xlab="Time",ylab=paste0("proportion in ",prov),ylim=c(0,1))
  points(y=toplot$n2_adj/(toplot$n1_adj+toplot$n2_adj+toplot$n3_adj),x=toplot$date,pch=21, col = "black", bg = alpha(col2, 0.7), cex=sqrt(toplot$n2)/5)#cex=(toplot$n2/log(10))/20)#cex=toplot$n2/50 )#cex = 0.5)
  points(y=toplot$n3_adj/(toplot$n1_adj+toplot$n2_adj+toplot$n3_adj),x=toplot$date,pch=21, col = "black", bg = alpha(col3, 0.7), cex=sqrt(toplot$n3)/5)#, cex=(toplot$n3/log(10))/20) #cex=toplot$n3/50 )#cex = 0.5)
  polygon(c(toplot$date, rev(toplot$date)), c(lowercurve1_weighted, rev(uppercurve1_weighted)),col = alpha(col2, 0.5))
  polygon(c(toplot$date, rev(toplot$date)), c(lowercurve2_weighted, rev(uppercurve2_weighted)),col = alpha(col3, 0.5))
  lines(y=(bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)/((1-bbfit[["p2"]]-bbfit[["p3"]])+bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)+bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time))),
        x=toplot$date,type="l")
  lines(y=(bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time)/((1-bbfit[["p2"]]-bbfit[["p3"]])+bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)+bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time))),
        x=toplot$date,type="l")
  str2=sprintf("%s: %s {%s, %s}",name2,format(round(bbfit[["s2"]],3),nsmall=3),format(round(myconf["s2","2.5 %"],3),nsmall=3),format(round(myconf["s2","97.5 %"],3),nsmall=3))
  str3=sprintf("%s: %s {%s, %s}",name3,format(round(bbfit[["s3"]],3),nsmall=3),format(round(myconf["s3","2.5 %"],3),nsmall=3),format(round(myconf["s3","97.5 %"],3),nsmall=3))
  text(x=toplot$date[1],y=0.95,str2,col = col2,pos=4, cex = 1)
  text(x=toplot$date[1],y=0.88,str3,col = col3,pos=4, cex = 1)
  #dev.off()
  
  ################################
  # Looking for a breakpoint
  ################################
  # Visually looking for breaks in the slope over time (formal breakpoint search
  # is in the two variant code).
  
  #png(file=paste0("logit_",i, ".png"))
  options( scipen = 5 )
  plot(y=toplot$n2/toplot$n1,x=toplot$date, pch=21, col = "black", bg = alpha(col2, 0.7), cex=sqrt(toplot$n2)/3,
       log="y",ylim=c(0.001,1000), yaxt = "n", xlab="Time",ylab=paste0("logit in ",prov))
  points(y=toplot$n3/toplot$n1,x=toplot$date, pch=21, col = "black", bg = alpha(col3, 0.7), cex=sqrt(toplot$n3)/3)
  lines(y=(bbfit[["p2"]]*exp(bbfit[["s2"]]*toplot$time)/(1-bbfit[["p2"]]-bbfit[["p3"]])),
        x=toplot$date, type="l",col="black")#, col=col2)
  lines(y=(bbfit[["p3"]]*exp(bbfit[["s3"]]*toplot$time)/(1-bbfit[["p2"]]-bbfit[["p3"]])),
        x=toplot$date, type="l",col = "black")#, col=col3)
  str2=sprintf("%s: %s {%s, %s}",name2,format(round(bbfit[["s2"]],3),nsmall=3),format(round(myconf["s2","2.5 %"],3),nsmall=3),format(round(myconf["s2","97.5 %"],3),nsmall=3))
  str3=sprintf("%s: %s {%s, %s}",name3,format(round(bbfit[["s3"]],3),nsmall=3),format(round(myconf["s3","2.5 %"],3),nsmall=3),format(round(myconf["s3","97.5 %"],3),nsmall=3))
  text(x=toplot$date[1],y=500,str2,col = col2,pos=4, cex = 1)
  text(x=toplot$date[1],y=200,str3,col = col3,pos=4, cex = 1)
  axis(2, at=c(0.001,0.01,0.1,1,10,100,1000), labels=c(0.001,0.01,0.1,1,10,100,1000))
  print(str3)
  #dev.off()
  
  #Bends suggest a changing selection over time (e.g., due to the impact of vaccinations
  #differentially impacting the variants). Sharper turns are more often due to NPI measures. 
}



