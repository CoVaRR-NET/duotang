library(splines)

parseCaseData<- function(maxDate = NA){
  if (is.na(maxDate)){
    stop("Expected a max cutoff date, got None")
  }
  #maxDate = maxdate
  BC<-read.csv(gzfile("data_needed/AgeCaseCountBC.csv.gz"), header=T)%>% 
    filter(Age_Group %in% c("90+", "80-89","70-79")) %>% #keep only the 70+ case counts
    group_by(Reported_Date) %>% #group data by reported date
    summarize(n=n()) %>% #get total count of num cases per day
    filter(Reported_Date > (as.Date(maxDate)-days(120))) %>%#keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (Reported_Date = as.Date(Reported_Date)) %>% #format the column as dates
    drop_na() #drop row if any col is NA
  
  AB <- read.csv(gzfile("data_needed/AgeCaseCountAB.csv.gz"), header=T)%>% 
    filter(`Age.group` %in% c("80+ years","70-79 years")) %>% #keep only the 70+ case counts
    group_by(`Date.reported`) %>% #group data by reported date
    summarize(n=n()) %>% #get total count of num cases per day
    filter(`Date.reported` > (as.Date(maxDate)-days(120))) %>%#take the last 120 days of data
    mutate (`Date.reported` = as.Date(`Date.reported`)) %>% #format the column as dates
    rename(Reported_Date = `Date.reported`) %>% #relabel date column.
    drop_na() #drop row if any col is NA
  
  QC <- read.csv(gzfile("data_needed/AgeCaseCountQC.csv.gz"), header=T)%>% 
    filter(Date != "Date inconnue") %>%
    filter(Nom %in% c("70-79 ans","80-89 ans","90 ans et plus")) %>% #keep only the 70+ case counts
    group_by(Date) %>%#group data by reported date
    summarize(n = sum(as.numeric(psi_quo_pos_n)))%>% #get total count of num cases per day
    filter(as.Date(Date) > (as.Date(maxDate)-days(120))) %>%#keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (Date = as.Date(Date)) %>% #format the column as dates
    rename(Reported_Date = Date) %>% #relabel date column.
    drop_na() #drop row if any col is NA

    #Case_Reported_Date, Age_Group
  ON <-read.csv(gzfile("data_needed/AgeCaseCountON.csv.gz"), header=T)%>% 
   filter(Age_Group%in% c("70s","80s","90+")) %>% #keep only the 70+ case counts
    group_by(Case_Reported_Date) %>%#group data by reported date
    summarize(n = n())%>% #get total count of num cases per day
    filter(Case_Reported_Date > (as.Date(maxDate)-days(120))) %>%##keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (Case_Reported_Date = as.Date(Case_Reported_Date)) %>% #format the column as dates
    rename(Reported_Date = Case_Reported_Date) %>% #relabel date column.
    drop_na() #drop row if any col is NA
  
  Canada <- read.csv(gzfile("data_needed/AgeCaseCountCAN.csv.gz"), header=T)%>% 
    filter(status == "cases") %>%
    filter(gender == "all") %>%
    filter(age_group %in% c("70 to 79","80+")) %>% #keep only the 70+ case counts
    group_by(date) %>%#group data by reported date
    summarize(n = sum(as.numeric(count)))%>% #get total count of num cases per day
    filter(date > (as.Date(maxDate)-days(120))) %>%##keep everything within the last 120 days from latest virrusseq colleection date. 
    mutate (date = as.Date(date)) %>% #format the column as dates
    rename(Reported_Date = date) %>% #relabel date column.
    drop_na() #drop row if any col is NA
  
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

#get smooth fit of casecounts
getCaseCountSmoothFit <- function(countData, knots=5){
  if (!c("Reported_Date", "n") %in% colnames(countData)){
    stop("Possible corrupted countData. Expected column: Reported_Date and n.")
  }
  return (smooth.spline(countData$Reported_Date, countData$n,nknots=knots))
}

getCaseCountSmoothFitWithLambda<-function(countData, lambda=0.001){
  if (!c("Reported_Date", "n") %in% colnames(countData)){
    stop("Possible corrupted countData. Expected column: Reported_Date and n.")
  }
  return(smooth.spline(log10(countData$n),lambda=lambda))
}

getCaseCountSmoothFitWithSpar<-function(countData, spar=0.8){
  if (!c("Reported_Date", "n") %in% colnames(countData)){
    stop("Possible corrupted countData. Expected column: Reported_Date and n.")
  }
  return(smooth.spline(log10(countData$n),spar=0.8))
}

CubicSplSmooth <- function(countData, df=7) {
  if (!c("Reported_Date", "n") %in% colnames(countData)){
    stop("Possible corrupted countData. Expected column: Reported_Date and n.")
  }
  #if (is.na(df)){df = ceiling(length(countData$n) / 20)}
  bs <- (lm(n ~ bs(Reported_Date, df = df), data = countData )$fit)
  return(bs)
}

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

CubicSplSmooth3 <- function(data, lambda=10^3) {
  Knots <- c(rep(1, 3), seq(M), rep(M, 3))
  X <- matrix(NA, M, M+2)
  for (t in 1:M) {
    for (n in 0:(M+1)) {
      X[t, n+1] <- BSplineBasis(3, Knots, n, t)
    }
  }
  Dsq <- diff(X, 2)
  a <- lm.fit(X, data[,2], lambda*t(Dsq) %*% Dsq)
  return(X %*% a$coefficients)
}


#plot the casecount by selection estimate. 
plotCaseCountByDate2 <- function(countData, lineFits, numActualDatapoints, filename=NA){
  #countData <- caseCountData
  #lineFits <-rev(caseSelectionLines)
  #numActualDatapoints <- 121
  #filename = "ON"
  if (!c("Reported_Date", "n") %in% colnames(countData)){
    stop("Possible corrupted countData. Expected column: Reported_Date and n.")
  }
  
  colors = list()
  rValues = list()
  for (i in seq(1:length(lineFits))){
    if (!c("line", "color", "names") %in% names(lineFits[[i]])){
      stop("Possible corrupted lineFits Expected key: line, color, name")
    }
    fitData <- lineFits[[i]]$line
    colnames(fitData) <- c("Reported_Date", lineFits[[i]]$names)
    countData<- merge(countData, fitData, by = "Reported_Date", all = T)
    colors[lineFits[[i]]$names] = lineFits[[i]]$color
    rValues[lineFits[[i]]$names] = round(log(rev(countData[[lineFits[[i]]$names]])[1]/rev(countData[[lineFits[[i]]$names]])[2]) * 100,2)
  }
  countData$type <- c(rep("actual", numActualDatapoints), rep("projection", nrow(countData) - numActualDatapoints))
  #view(countData)
  d <- countData %>% melt(id = c("Reported_Date", "n", "CaseCount", "type")) 
  d$variable <- factor(d$variable , levels=levels(fct_relevel(sort(levels(d$variable)), "The Rest", after=0)))
  legendValues <- d %>% dplyr::select(variable) %>% mutate(variable = as.character(variable)) %>% unique() %>% 
    mutate(colorToUse = colors[variable]) %>% mutate(nameWithR = paste0(variable, "\n(r = ", rValues[variable], "%)")) %>%
    arrange(factor(variable, levels = levels(d$variable)))
  legendColors <- legendValues$colorToUse
  legendLabels <- legendValues$nameWithR
  #duplicate the last row of the actual data so projections are show continiously.
  lastDayActual <- d %>% filter(type == "actual") %>% filter(Reported_Date == max(Reported_Date)) %>% mutate(type="projection")
  #firstDayProjectiond <- d %>% filter(type == "projection") %>% filter(Reported_Date == min(Reported_Date)) %>% mutate(type="actual")
  d <- rbind(d, lastDayActual) #%>% rbind(firstDayProjectiond)
  #view(d %>% filter(type=="actual"))
  p<- ggplot() +
    geom_area(data = d[d$type=="actual",], mapping = aes(x=Reported_Date, y=value, fill=variable),size = 0.5, alpha = 0.6, color="white", linetype="solid")+
    geom_area(data = d[d$type=="projection",], mapping = aes(x=Reported_Date, y=value, fill=variable), size = 0.5, alpha = 0.3,color="white",  linetype="dotted")+
    #geom_area(data = d, mapping = aes(x=Reported_Date, y=value, fill=variable, alpha=type))+
    scale_fill_manual(name = "Variants", labels = legendLabels, values = legendColors) +
    #scale_alpha_manual(name = NULL, labels = c("Actual", "Projected"), values = c(0.6, 0.4)) +
    geom_line(data = d, mapping = aes(x=Reported_Date, y=CaseCount, linetype = "Total Cases"), color = 'darkgreen', size = 1) +
    scale_linetype_manual(name = NULL, labels = c(paste0("Total \n(r = ", rValues["CaseCount"], "%)")), values = c("solid"))+
    geom_point(data = d, mapping = aes(x = Reported_Date, y=n, shape="Cases per day"), size=2, color = "limegreen") +
    scale_shape_manual(name = NULL, labels = c("Cases per day"), values=c(19)) +
    ylim(0, max(countData$n)) + 
    xlab("Sample collection date") +
    ylab("Age 70+ case count") +
    labs(caption = paste0("Last day of genomic data (Darker colors) is ", max((d %>% filter(type=="actual"))$Reported_Date),
                          "\n Last day of cases count data is ", max((d %>% filter(type=="projection"))$Reported_Date))) +
    theme_bw() 
  
  
  
    if (!is.na(filename)){
      p <- p + ggtitle(paste0("Dataset: ", filename))
      ggsave(paste0("casecount_",filename, ".png"), plot = p, width = 11, height = 8)
    }
  return (p)
}


plotCaseCountByDate <- function(countData, lineFits, filename=NA ){
  countData <- caseCountData
  lineFits <-rev(caseSelectionLines)
  if (!c("Reported_Date", "n") %in% colnames(countData)){
    stop("Possible corrupted countData. Expected column: Reported_Date and n.")
  }
  plot(countData$Reported_Date, as.numeric(countData$n), 
       xaxt="n", xlab="Sample collection date",
       ylim=c(0,max(countData$n)+20), ylab="Age 60+ Case Counts",  
       pch = 20, col = "limegreen")
  axis(side = 1, at = pretty(countData$Reported_Date), label = format(pretty(countData$Reported_Date),"%b"))
  for (i in seq(1:length(lineFits))){
    if (!c("line", "color", "names") %in% names(lineFits[[i]])){
      stop("Possible corrupted lineFits Expected key: line, color, name")
    }
    X <- countData$Reported_Date[0:length(lineFits[[i]]$line)]
    Y <- lineFits[[i]]$line
    color <-lineFits[[i]]$color
    print(i)
    
    if (i != length(lineFits)){
      for (j in seq(1:i)){
        if (j == i){
          Y <- Y
        } else{
          Y <- Y + lineFits[[j]]$line
        }
      }
    }

    lines(X, Y, col=color, lwd=2)
    r = log(rev(Y)[1]/rev(Y)[2]) * 100
    text(x=X[1]-5, y=(max(countData$n) + 20 - ((max(countData$n)/20)*(i-1))), paste0 (lineFits[[i]]$names, " (r = ", round(r, 2),"%)"), col=color, pos=4, cex = 0.85)
    
    if (lineFits[[i]]$names != "CaseCount"){
      polygon(c(min(X),X, max(X)),c(min(Y),Y, max(Y)), col = alpha(color, 0.4))
    }
  }
  if (!is.na(filename)){
    title(main=paste0("Dataset: ", filename))
    dev.copy(png,paste0("casecount_",filename, ".png"))
    dev.off()
  }
}
