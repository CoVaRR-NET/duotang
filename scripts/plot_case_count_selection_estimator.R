library(splines)

#' Reads in case count data from files in $data_dir for each province
#' Return a named list for each province with key=shortname and value=df
#' @param maxDate:  the maximum date to cutoff the data. Default=NA
#' @param datadir:  the data directory where the agecount data is stored. Default='data_needed'
parseCaseDataByAge_deprecated<- function(maxDate = Sys.Date(), datadir = "./data_needed"){
  #maxDate = maxdate
  BC<-read.csv(gzfile(paste0(datadir, "/AgeCaseCountBC.csv.gz")), header=T)%>% 
    filter(Age_Group %in% c("90+", "80-89","70-79")) %>% #keep only the 70+ case counts
    group_by(Reported_Date) %>% #group data by reported date
    summarize(n=n()) %>% #get total count of num cases per day
    filter(Reported_Date > (as.Date(maxDate)-days(120))) %>%#keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (Reported_Date = as.Date(Reported_Date)) %>% #format the column as dates
    drop_na() #drop row if any col is NA
  
  AB <- read.csv(gzfile(paste0(datadir,"/AgeCaseCountAB.csv.gz")), header=T)%>% 
    filter(`Age.group` %in% c("80+ years","70-79 years")) %>% #keep only the 70+ case counts
    group_by(`Date.reported`) %>% #group data by reported date
    summarize(n=n()) %>% #get total count of num cases per day
    filter(`Date.reported` > (as.Date(maxDate)-days(120))) %>%#take the last 120 days of data
    mutate (`Date.reported` = as.Date(`Date.reported`)) %>% #format the column as dates
    rename(Reported_Date = `Date.reported`) %>% #relabel date column.
    drop_na() #drop row if any col is NA
  #view(QC)
  #colnames(QC)
  QC <- read.csv(gzfile(paste0(datadir,"/AgeCaseCountQC.csv.gz")), header=T)%>% 
    mutate(Date = .[,1]) %>% 
    filter(Date != "Date inconnue") %>%
    filter(Nom %in% c("70-79 ans","80-89 ans","90 ans et plus")) %>% #keep only the 70+ case counts
    group_by(Date) %>%#group data by reported date
    summarize(n = sum(as.numeric(psi_quo_pos_n)))%>% #get total count of num cases per day
    filter(as.Date(Date) > (as.Date(maxDate)-days(120))) %>%#keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (Date = as.Date(Date)) %>% #format the column as dates
    rename(Reported_Date = Date) %>% #relabel date column.
    drop_na() #drop row if any col is NA

    #Case_Reported_Date, Age_Group
  ON <-read.csv(gzfile(paste0(datadir,"/AgeCaseCountON.csv.gz")), header=T)%>% 
   filter(Age_Group%in% c("70s","80s","90+")) %>% #keep only the 70+ case counts
    group_by(Case_Reported_Date) %>%#group data by reported date
    summarize(n = n())%>% #get total count of num cases per day
    filter(Case_Reported_Date > (as.Date(maxDate)-days(120))) %>%##keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (Case_Reported_Date = as.Date(Case_Reported_Date)) %>% #format the column as dates
    rename(Reported_Date = Case_Reported_Date) %>% #relabel date column.
    drop_na() #drop row if any col is NA
  
  Canada <- read.csv(gzfile(paste0(datadir,"/AgeCaseCountCAN.csv.gz")), header=T)%>% 
    filter(status == "cases") %>%
    filter(gender == "all") %>%
    filter(age_group %in% c("70 to 79","80+")) %>% #keep only the 70+ case counts
    group_by(date) %>%#group data by reported date
    summarize(n = sum(as.numeric(count)))%>% #get total count of num cases per day
    filter(date > (as.Date(maxDate)-days(120))) %>%##keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (date = as.Date(date)) %>% #format the column as dates
    rename(Reported_Date = date) %>% #relabel date column.
    drop_na() #drop row if any col is NA
  #this data havent been updated since Feb 2022
   #SK <- read.csv("data_needed/AgeCaseCountSK.csv", header=T) %>%
  #  filter(Region == "Total") %>% select (Date, Age.60.to.79, Age.80.) %>% #take the rows and columns we need
  #  mutate(Age60.79 =  Age.60.to.79 - lag( Age.60.to.79, default = 0)) %>% #get the diff to previos cell for age 60-79, this is the new per day
  #  mutate(Age80 =  Age.80. - lag( Age.80., default = 0)) %>%  # #get the diff to previos cell for age 80+, this is the new per day
  #  mutate(n = Age60.79 + Age.80.) %>% select (Date, n)%>%  #sum to total per day
  #  rename(Reported_Date = Date) %>% #relabel date column. 
  #  mutate (Reported_Date = as.Date(Reported_Date)) %>% #format the column as dates
  #  filter(Reported_Date > (as.Date(maxDate)-days(120))) #keep everything within the last 120 days from latest virrusseq colleection date. 
    
  return (list("BC" = BC, "ON" = ON, "QC"=QC, "AB"=AB, "Canada"=Canada))#, "SK"=SK))
}

#' Reads in case count data from files in $data_dir for each province
#' Return a named list for each province with key=shortname and value=df
#' THIS CODE IS DEPRECATED DUE TO HEALTH-INFOBASE STOPPED REPORTING CASE COUNTS.USE parsePositivityData() instead.
#' @param maxDate:  the maximum date to cutoff the data. Default=NA
#' @param datadir:  the data directory where the agecount data is stored. Default='data_needed'
parseCaseData.deprecated<- function(all.regions = all.regions, maxDate = params$datestamp, datadir = "./data_needed"){
  #maxDate = Sys.Date()
  #datadir = "./data_needed"
  caseCounts <- list()
  
  for (i in 1:length(all.regions[["name"]])){
    CC <-read.csv(gzfile(paste0(datadir, "/AgeCaseCountCAN.csv.gz")), header=T)%>% 
      filter(prname == all.regions[["name"]][i]) %>% #keep only the 70+ case counts
      filter(date > startdate) %>%#keep everything within the last 120 days from latest virrusseq colleection date. 
      mutate (date = as.Date(date)) %>% #format the column as dates
      dplyr::select(date, numtotal_last7) %>%
      drop_na()  #drop row if any col is NA
    
    colnames(CC) <- c("Reported_Date","n")
    
    if (nrow(CC) > 4){
      caseCounts[[all.regions[["shortname"]][[i]]]] <- CC
    } else{
      #caseCounts[[all.regions[["shortname"]][[i]]]] <- NA
    }
  }
  
  if (file.exists(paste0(datadir,"/AgeCaseCountAB.csv.gz"))){
    caseCounts[["AB"]] <- read.csv(gzfile(paste0(datadir,"/AgeCaseCountAB.csv.gz")), header=T)%>% 
      filter(`Date.reported.to.Alberta.Health` > startdate) %>%#take the last 120 days of data
      mutate (`Date.reported.to.Alberta.Health` = as.Date(`Date.reported.to.Alberta.Health`)) %>% #format the column as dates
     # drop_na() %>% #drop row if any col is NA
      dplyr::select(`Date.reported.to.Alberta.Health`, `Number.of.cases`)
    colnames(caseCounts[["AB"]]) <- c("Reported_Date", "n")
      }

  if (file.exists(paste0(datadir,"/AgeCaseCountQC.csv.gz"))){
    caseCounts[["QC"]] <- read.csv(gzfile(paste0(datadir,"/AgeCaseCountQC.csv.gz")), header=T, encoding = "UTF-8")%>% 
      mutate(Date = .[,1]) %>% 
      filter(Date != "Date inconnue") %>%
      filter(Regroupement == "Sexe") %>% #use the total count from the sexe category because Paphlagon dont like UTF-8
      filter(Nom == "Total") %>% 
      group_by(Date) %>%#group data by reported date
      summarize(n = sum(as.numeric(psi_quo_pos_n)))%>% #get total count of num cases per day
      filter(as.Date(Date) > startdate) %>%#keep everything within the last 120 days from latest virrusseq colleection date. 
      mutate (Date = as.Date(Date)) %>% #format the column as dates
      rename(Reported_Date = Date) %>% #relabel date column.
      drop_na() #drop row if any col is NA
  }
  #view(caseCounts[["QC"]])
  if (file.exists(paste0(datadir,"/AgeCaseCountON.csv.gz"))){
    caseCounts[["ON"]] <-read.csv(gzfile(paste0(datadir,"/AgeCaseCountON.csv.gz")), header=T)%>% 
      group_by(Case_Reported_Date) %>%#group data by reported date
      summarize(n = n())%>% #get total count of num cases per day
      filter(Case_Reported_Date > startdate) %>%##keep everything within the last 120 days from latest virrusseq colleection date. 
      mutate (Case_Reported_Date = as.Date(Case_Reported_Date)) %>% #format the column as dates
      rename(Reported_Date = Case_Reported_Date) %>% #relabel date column.
      drop_na() #drop row if any col is NA
  }

  
  return (caseCounts)#, "SK"=SK))
}


parsePositivityData <- function(all.regions = all.regions, maxDate = params$datestamp, datadir = "./data_needed"){
  caseCounts <- list()
  
  for (i in 1:length(all.regions[["name"]])){
    CC <-read.csv((paste0(datadir, "/CanPositivityData.csv")), header=T)%>% 
      filter(prname == all.regions[["name"]][i]) %>% #keep only the 70+ case counts
      filter(date > startdate) %>%#keep everything within the last 120 days from latest virrusseq colleection date. 
      mutate (date = as.Date(date)) %>% #format the column as dates
      dplyr::select(date, numtests_weekly, percentpositivity_weekly) %>%
      drop_na() %>% #drop row if any col is NA
      mutate(totalPositive = numtests_weekly * (percentpositivity_weekly / 100)) %>% 
      dplyr::select(date, totalPositive)
    colnames(CC) <- c("Reported_Date","n")
    
    if (nrow(CC) > 4){
      caseCounts[[all.regions[["shortname"]][[i]]]] <- CC
    } else{
      #caseCounts[[all.regions[["shortname"]][[i]]]] <- NA
    }
  }
  return(caseCounts)
}

#' get smooth fit of casecounts using knots
getCaseCountSmoothFit <- function(countData, knots=5){
  return (smooth.spline(countData$Reported_Date, countData$n,nknots=knots))
}

#' get smooth fit of casecounts using lambda. THIS IS THE ONE CURRENTLY USED.
getCaseCountSmoothFitWithLambda<-function(countData, lambda=0.001){
  return(smooth.spline(log10(countData$n),lambda=lambda))
}

#' get smooth fit of casecounts using spar. 
getCaseCountSmoothFitWithSpar<-function(countData, spar=0.8){
  return(smooth.spline(log10(countData$n),spar=0.8))
}

#' The R implementation of the mathematica cublic spline algo. Seems incorrect tho.
CubicSplSmooth <- function(countData, df=7) {
  #if (is.na(df)){df = ceiling(length(countData$n) / 20)}
  bs <- (lm(n ~ bs(Reported_Date, df = df), data = countData )$fit)
  return(bs)
}

#' An translation of the mathematica cublic spline algo by Sally
CubicSplSmooth2 <- function(data, lambda=10^3) {
  data <- caseData$QC
  #data is a datafrome of 2 columns (date,n)
  M <- nrow(data)
  data$n <- log(data$n)
  Knots <- c(1, 1,seq(1,M),M,M,M)
  X <- bs(data$n, degree =3, knots = Knots)
  Dsq <- diff(X, differences = 2)
  a <- t(X) %*% X + lambda * t(Dsq) %*% Dsq
  b <- t(X) %*% data$n
  s <- solve(a,b)
  r <- X %*% s
  return(r)
}

#' plot the casecount by selection estimate. 
plotCaseCountByDate2 <- function(countData, lineFits, population, order, maxdate = NA,region=NA, saveToFile=F){
  # countData <- caseCountData
  # lineFits <-rev(caseSelectionLines)
  # region = "Alberta"
  # order=mutantNames
  # filename = "test"
   rColors = list()
   rValues = list()
  #  
  #  view(lineFits)
  # 
  order[[length(order)]] = paste0(order[[length(order)]], " (Reference)")
  
  #format each of the fit lines for different variants
  for (i in seq(1:length(lineFits))){
    fitData <- lineFits[[i]]$line
    colnames(fitData) <- c("Reported_Date", lineFits[[i]]$names, "type")
    countData<- merge(countData, fitData %>% dplyr::select(-type), by = "Reported_Date", all = T) #merge the X values
    rColors[lineFits[[i]]$names] <- lineFits[[i]]$color #assign color to line
    rValues[lineFits[[i]]$names] <- round(log(rev(countData[[lineFits[[i]]$names]])[1]/rev(countData[[lineFits[[i]]$names]])[2]) * 100,2) #calculate the R value
    rValues[lineFits[[i]]$names] <- as.numeric(rValues[lineFits[[i]]$names]) / 7 #get the per day selection coefficient
    
  }
  names(rValues)[names(rValues) == "The Rest"] <- paste0(mutantNames[[length(mutantNames)]], " (Reference)")
  names(rColors)[names(rColors) == "The Rest"] <- paste0(mutantNames[[length(mutantNames)]], " (Reference)")
  
  countData$type <- lineFits[[2]]$line$type
  
  #melt the DF for plotting
  d <- countData %>% melt(id = c("Reported_Date", "n", "CaseCount", "report_type", "type")) %>% 
    mutate(variable = str_replace(variable, "The Rest", paste0(mutantNames[[length(mutantNames)]], " (Reference)")))
    #sort the order of the mutants according to the order variable. If not defined, sort alphabetically.
  if (length(order) > 0){
    d$variable <- factor(d$variable , levels=c(order[length(order)], order[1:length(order)-1] ))
  } else{
    d$variable <- factor(d$variable , levels=levels(fct_relevel((levels(d$variable)), "The Rest", after=0)))
  }
  
  legendValues <- d %>% dplyr::select(variable) %>% mutate(variable = as.character(variable)) %>% unique() %>% 
    mutate(colorToUse = rColors[variable]) %>% 
    mutate(nameWithR = paste0(variable, "\n(r = ", round(as.numeric(rValues[variable]),0), "%)")) %>%
    arrange(factor(variable, levels = levels(d$variable))) #generate legend labels
	
	#add color and labels to the melted DF.
  legendColors <- legendValues$colorToUse
  legendLabels <- legendValues$nameWithR
  #duplicate the last row of the actual/accurate data so projections are show continiously.
  lastDayActual <- d %>% filter(type == "Actual") %>% filter(Reported_Date == max(Reported_Date)) %>% mutate(type="Projected")
  lastDayAccurate <- d %>% filter(report_type == "Accurate") %>% filter(Reported_Date == max(Reported_Date)) %>% mutate(report_type="UnderReported")
  lastDayAccurate$value=NA
  d <- rbind(d, lastDayActual) %>% rbind(lastDayAccurate)
  
  #convert to per 100k people
  d$n <- (d$n*100000)/population
  d$value <- (d$value*100000)/population
  d$CaseCount <- (d$CaseCount*100000)/population

  caseCountLabel <- paste0("Case Count\n(r = ", round(as.numeric(rValues["CaseCount"]),0), "%)")
  
  #plot
  p<- ggplot() +
    geom_area(data = d[d$type=="Actual" & d$report_type=="Accurate",], mapping = aes(x=Reported_Date, y=value, fill=variable),size = 0.5, alpha = 0.6, color="white", linetype="solid")+
    geom_area(data = d[d$type=="Projected" & d$report_type=="Accurate",], mapping = aes(x=Reported_Date, y=value, fill=variable), size = 0.5, alpha = 0.3,color="white",  linetype="dotted")+
    #geom_area(data = d, mapping = aes(x=Reported_Date, y=value, fill=variable, alpha=type))+
    scale_fill_manual(name = "Variants", labels = legendLabels, values = legendColors) +
    #scale_alpha_manual(name = NULL, labels = c("Actual", "Projected"), values = c(0.6, 0.4)) +    
    geom_point(data = d, mapping = aes(x = Reported_Date, y=n, shape=report_type), size=2, color = "limegreen") +
    #scale_shape_manual(name = NULL, values=c(19)) +
    scale_shape_manual(name = caseCountLabel, labels = c("Accurate", "Under Reported"), values = c(19, 1)) +
    geom_line(data = d[d$report_type=="Accurate",], mapping = aes(x=Reported_Date, y=CaseCount), color = 'darkgreen', size = 1) +
    #ylim(0, max(6, max(d$n) + 2)) + 
    ylim(0, 6) + 
    xlim(min(d$Reported_Date), maxdate) +
    xlab("Sample collection date") +
    ylab(paste0("Number of detections in ", region, " per 100,000 individuals")) +

    theme_bw() +
    guides(`Case Count` = guide_legend(order = 0),
           Variants = guide_legend(order =2)) +
    labs(caption = paste0("Lighter shade: per lineage case counts estimated using available genomics data",
                          "\nLast day of genomic data is ", max((d %>% filter(type=="Actual"))$Reported_Date),
                          "\n Last day of accurate detection count is ", max((d %>% filter(report_type=="Accurate"))$Reported_Date))) +
    theme(legend.text=element_text(size=12), text = element_text(size = 20)) 
  
    if (saveToFile){
      p <- p + ggtitle(paste0("Dataset: ", region))
      ggsave(paste0("casecount_",region, ".png"), plot = p, width = 11, height = 8)
    }
  return (p)
}
