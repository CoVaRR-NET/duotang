library(tidyverse)
library(ggplot2)
library(ggpubr)

datadir = "data_needed"

#format outbreak data
outbreakCounts <- read_tsv(paste0(datadir,"/outbreakCounts.tsv")) %>% group_by(date) %>% mutate(total = sum(n)) %>% dplyr::select(-type, -n, -year) %>% unique() 
outbreakCounts$date <- as.Date(outbreakCounts$date,  format="%m/%d/%Y")

view(outbreakCounts)
#format epi data
epidataCANall <- read.csv(paste0(datadir, "/CanadianEpiData.csv"))
epidataCANall$date <- as.Date(epidataCANall$date)
epidataCANall$prname <- gsub('_', ' ', epidataCANall$prname)
epidate <- tail(epidataCANall,1)$date #download date

epidataCANall$previousvalue <- 0
# #small loop to get the numtoday column from previous versions of this file from the cumulative cases
for(row in 1:nrow(epidataCANall)) {
  p <- epidataCANall[row, "prname"]
  subdf <- epidataCANall[which(
    (epidataCANall$date > epidataCANall[row, "date"] & epidataCANall$prname==p)
  ), ]
  if(nrow(subdf) != 0) {
    nextrow <- which( (epidataCANall$date == min(subdf$date) & epidataCANall$prname==p))
    epidataCANall[nextrow, "previousvalue"] <- epidataCANall[row, "totalcases"]
  }
}
epidataCANall$numtoday <- epidataCANall$totalcases - epidataCANall$previousvalue
epidataCANall <- epidataCANall %>% filter (prname == "Canada") %>% filter (reporting_year >= 2023) %>% dplyr::select(date, numtotal_last7) 

view(epidataCANall)

#case count by gender data
caseCountDataGender <- read_csv(paste0(datadir,"/caseCountDataCAN.csv")) %>% filter(status == "cases" & age_group == "all" &  gender == "all") %>% dplyr::select(date, rate_per_100000)
caseCountDataGender$date <- as.Date(caseCountDataGender$date)

view(caseCountDataGender)

#positivity Data
positivityData <- read_csv(paste0(datadir,"/Positivity.csv")) %>% mutate(CanPos = `Can Tests` * `HCoV%...4` / 100 ) %>% dplyr::select(`Week End`, `CanPos`, `HCoV%...4`) %>% mutate
colnames(positivityData) = c("date", "count", "percent")
positivityData$date <- as.Date(positivityData$date,  format="%m/%d/%Y")
#positivityData <- positivityData %>% mutate (date2 = date-weeks(1))
view(positivityData)
#combine them all
data <- outbreakCounts %>% 
  left_join(epidataCANall, by = "date") %>% drop_na() %>% 
  left_join(caseCountDataGender, by = "date") %>% drop_na()%>% 
  left_join(positivityData, by = "date") %>% drop_na()
colnames(data) <- c("Week", "Outbreaks_Count",  "Cases_Count", "Gender_Cases_rate", "Positive_Count", "Positive_Rate")
data$Outbreaks_Count <- as.numeric(data$Outbreaks_Count)
data$Cases_Count <- as.numeric(data$Cases_Count)
data$Gender_Cases_Count <- as.numeric(data$Gender_Cases_rate)
data$Positive_Count <- as.numeric(data$Positive_Count)
data$Positive_Rate <- as.numeric(data$Positive_Rate)

data <- data %>% drop_na()
view(data)


correlateAndPlot <- function(data, groupToCompare){
 # groupToCompare = "Positive_Rate"
  correlation <- cor(data$Cases_Count, data[[groupToCompare]])
  correlation_text <- paste("r=", round(correlation, 2))
  
  data <- data %>% mutate (colorCode = ifelse(Week >= as.Date("2024-04-29"), 'red', 'blue'))
  
  p <- ggplot(data, aes(x=Cases_Count, y=!!sym(groupToCompare))) +
    geom_point(color=data$colorCode) +         # Scatter plot
    geom_smooth(method='lm', col='black') +  # Regression line
    ggtitle(paste0("Canada wide Cases versus ",groupToCompare, " correlation")) +
    xlab("Case Count") +
    ylab(groupToCompare) +
    theme_minimal()
  
  p <- p + annotate("text", x = 5000, y = max(data[[groupToCompare]]) - 5, 
                    label = correlation_text, size = 5, color = "black")
  
  ggsave(paste0("CaseCount_vs_",groupToCompare,".JPG"), p)
  p
}

data <- data %>% filter (Week > as.Date("2024-01-01"))

correlateAndPlot(data, "Outbreaks_Count")
correlateAndPlot(data, "Gender_Cases_rate")
correlateAndPlot(data, "Positive_Count")
correlateAndPlot(data, "Positive_Rate")
write_tsv(data, "counts.tsv")
