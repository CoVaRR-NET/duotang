#@Author = Arnaud N’Guessan

#previous versions of the code were published here: 
# https://github.com/arnaud00013/SARS_CoV_2_haplotypes_Tajima_D_2020_time_series and were used in two publications:
# Mostefai et al. (2022) Data-driven approaches for genetic characterization of SARS-CoV-2 lineages, Frontiers in Medicine
# Murall et al. (2021) A small number of early introductions seeded widespread transmission of SARS-CoV-2 in Quebec, Canada, Genome Medicine

#This script compute Tajima's D and dN/dS using SARS-CoV-2 consensus sequences 

#requires 4 input files in the working directory:
#1. alignment fasta
#2. metadata csv
#3. case counts over time csv
#4. reference seq (MN908947_3.fasta)

#Time code execution
library("tictoc")
tic()
#start_time <- Sys.time()

#import libraries
library("ggplot2")
library("seqinr")
library("genbankr")
library("grid")
library("RColorBrewer")
library("randomcoloR")
library("gplots")
library("lmPerm")
library("ggpubr")
library("gridExtra")
library("tidyr")
library("Cairo")
library("parallel")
library("foreach")
library("doParallel")
library("FD")
library("vegan")
library("session")
library("infotheo")

setwd("C:/path/Tajima_D_and_dN_dS_example_code/")

#import script arguments
output_workspace <- as.character("C:/path/Tajima_D_and_dN_dS_example_code/")
#output_workspace <- as.character(commandArgs(TRUE)[1]) #ABSOLUTE Path of the folder containing the data (fasta and metadata)
nb_cores <- 4 #as.integer(commandArgs(TRUE)[2]) #Number of cpus
#Number of cpus for Tajima's D analysis. It corresponds to the number of months that will be analyzed in parallel. Thus, it should be <=7 for Wave 1.

#min_date <- as.character(commandArgs(TRUE)[3]) #Date at which the analyses of the consensus sequences should start
#max_date <- as.character(commandArgs(TRUE)[4]) #Date at which the analyses of the consensus sequences should end

#Set language as English for date formatting
Sys.setlocale("LC_ALL","English")

#create dataframe with samples consensus seq 
df_fasta_consensus_seq <- read.csv2(file = paste0(output_workspace,"testdataset250.fasta"),sep = "\t",header = F,stringsAsFactors = FALSE) #sep = ",",
df_consensus_seq <- data.frame(Sample=unname(vapply(X = df_fasta_consensus_seq[which((1:nrow(df_fasta_consensus_seq))%%2==1),1],FUN= function(x) substr(x,2,nchar(x)),FUN.VALUE = c(""))),Consensus_seq=df_fasta_consensus_seq[which((1:nrow(df_fasta_consensus_seq))%%2==0),1],stringsAsFactors = F)
rownames(df_consensus_seq) <- df_consensus_seq$Sample

#import metadata 
df_metadata_samples <- read.csv2(file = paste0(output_workspace,"testdataset250_metadata.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
df_metadata_samples$X <- NULL
rownames(df_metadata_samples) <- df_metadata_samples$strain
min_date <- min(df_metadata_samples$date) #Date at which the analyses of the consensus sequences should start
max_date <- max(df_metadata_samples$date) #Date at which the analyses of the consensus sequences should end

#Only keep consensus sequences for which we have metadata
df_consensus_seq <- df_consensus_seq[rownames(df_metadata_samples),]

#Qc first wave confirmed cases (https://www.inspq.qc.ca/covid-19/donnees, INSPQ, 2020)
df_confirmed_cases_QC <- read.csv2(file = paste0(output_workspace,"Qc_nb_of_confirmed_cases.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
names(df_confirmed_cases_QC) <- c("date","from_epi_link","from_lab")
df_confirmed_cases_QC$total_nb_cases <- df_confirmed_cases_QC$from_epi_link+df_confirmed_cases_QC$from_lab
rownames(df_confirmed_cases_QC) <- df_confirmed_cases_QC$date
df_confirmed_cases_QC <- df_confirmed_cases_QC[((df_confirmed_cases_QC$date<max(as.Date(df_metadata_samples$date)))&(df_confirmed_cases_QC$date>min(as.Date(df_metadata_samples$date)))),]


time_period_length <- 14 #number of days

nb_time_periods <- ceiling(as.numeric(as.Date(max_date)-as.Date(min_date))/time_period_length)
df_time_periods <- data.frame(time_period=1:nb_time_periods,start=as.Date(min_date)+(time_period_length*(0:(nb_time_periods-1))),stop=(as.Date(min_date)+(time_period_length-1))+(time_period_length*(0:(nb_time_periods-1))),Tajima_D=NA,stringsAsFactors = FALSE)
df_time_periods$middle_day <- as.Date(df_time_periods$start)+(time_period_length/2)


#function for plotting linear model
ggplotRegression <- function (fit,ggsave_path,the_filename,xlabl=NA,ylabl=NA) {
  library(ggplot2)
  bool_gg_save <- TRUE
  if(is.na(xlabl)){
    xlabl <- names(fit$model)[2]
  }
  if(is.na(ylabl)){
    ylabl <- names(fit$model)[1]
  }
  adj_r_sq <- formatC(summary(fit)$adj.r.squared, format = "e", digits = 3)
  slope <-formatC(summary(fit)$coefficients[,1][2], format = "e", digits = 3)
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = formatC(unname(summary(fit)$coefficients[,3][2]), format = "e", digits = 3)),no=formatC(broom::glance(fit)$p.value, format = "e", digits = 3))
  tryCatch(expr = {ggplot(fit$model, aes_string(x = names(fit$model)[2], y = names(fit$model)[1])) +
      geom_point() +
      stat_smooth(method = "lm", col = "red") +
      xlab(xlabl)+
      ylab(ylabl)+
      labs(title = paste("Adj R2 = ",adj_r_sq,
                         " Slope =",slope,
                         " P =",p_val))+ theme(plot.title=element_text(hjust=0,size=12))},error=function(e) bool_gg_save <- FALSE)
  
  if (bool_gg_save){
    ggsave(filename = the_filename, path=ggsave_path, width = 15, height = 10, units = "cm")
  }else{
    print(paste0(the_filename, "won't be created because of it is irrelevant for gene in path ", ggsave_path))
  }
  #return result as the real float numbers
  adj_r_sq <- unname(summary(fit)$adj.r.squared)
  slope <-unname(summary(fit)$coefficients[,1][2])
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = unname(summary(fit)$coefficients[,3][2])),no=summary(fit)$coefficients[,2][2])
  return(list(adj_r_sq_current_lm = adj_r_sq,slope_current_lm = slope,p_val_current_lm=p_val))
}

ggplotRegression_export_eps <- function (fit,ggsave_path,the_filename,xlabl=NA,ylabl=NA) {
  library(ggplot2)
  bool_gg_save <- TRUE
  if(is.na(xlabl)){
    xlabl <- names(fit$model)[2]
  }
  if(is.na(ylabl)){
    ylabl <- names(fit$model)[1]
  }
  adj_r_sq <- formatC(summary(fit)$adj.r.squared, format = "e", digits = 3)
  slope <-formatC(summary(fit)$coefficients[,1][2], format = "e", digits = 3)
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = formatC(unname(summary(fit)$coefficients[,3][2]), format = "e", digits = 3)),no=formatC(broom::glance(fit)$p.value, format = "e", digits = 3))
  tryCatch(expr = {ggplot(fit$model, aes_string(x = names(fit$model)[2], y = names(fit$model)[1])) +
      geom_point() +
      stat_smooth(method = "lm", col = "red") +
      xlab(xlabl)+
      ylab(ylabl)+
      labs(title = paste("Adj R2 = ",adj_r_sq,
                         " Slope =",slope,
                         " P =",p_val))+ theme(plot.title=element_text(hjust=0,size=12))},error=function(e) bool_gg_save <- FALSE)
  
  if (bool_gg_save){
    ggsave(filename = the_filename, path=ggsave_path, width = 15, height = 10, units = "cm", device = cairo_ps)
  }else{
    print(paste0(the_filename, "won't be created because of it is irrelevant for gene in path ", ggsave_path))
  }
  #return result as the real float numbers
  adj_r_sq <- unname(summary(fit)$adj.r.squared)
  slope <-unname(summary(fit)$coefficients[,1][2])
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = unname(summary(fit)$coefficients[,3][2])),no=ifelse(test = unname(summary(fit)$coefficients[,4][2])<(2e-16),yes = "<2e-16",no = unname(summary(fit)$coefficients[,4][2])))
  return(list(adj_r_sq_current_lm = adj_r_sq,slope_current_lm = slope,p_val_current_lm=p_val))
}

#function to get the number of cases detected during a certain time period
get_time_period_nb_cases <- function(the_time_period){
  nb_cases_current_time_period <- sum(df_confirmed_cases_QC[(as.Date(df_confirmed_cases_QC$date)>=df_time_periods$start[the_time_period])&(as.Date(df_confirmed_cases_QC$date)<=df_time_periods$stop[the_time_period]),"total_nb_cases"])
  
  return(nb_cases_current_time_period)
}

#create a function that does all possible pariwise COMPARISONS between a set of unique sequences 
#THE FUNCTION TAKES INTO ACCOUNT THE PRESENCE OF AMBIGUOUS CONSENSUS CALLS ("N")
#Execution time is O(n^2)
calculate_nb_pwd <- function(v_seqs){
  output <- 0 #initialize the variable that will contain the number of pairwise differences in single nucleotide sites
  pwdiff_with_others<- function(the_sequence,lst_unique_sequences){
    if (any(duplicated(lst_unique_sequences))){
      stop("There are doublons in the list of unique sequences.  Retry!")
    }
    result<-rep(NA,length(lst_unique_sequences))
    ind_res_list<-1
    for (current_diff_sequence in lst_unique_sequences){
      current_result<-0
      for (i in 1:nchar(v_seqs[1])){
        if ((substr(x = the_sequence,i,i)!=substr(x = current_diff_sequence,i,i))&(substr(x = the_sequence,i,i)!="N")&("N"!=substr(x = current_diff_sequence,i,i))){
          current_result <- current_result +1
        }
      }
      result[ind_res_list] <- current_result
      ind_res_list <- ind_res_list + 1
    }
    return(result)
  }
  v_unique_freqs <- list(table(v_seqs))[[1]]
  
  #comparisons are not duplicated here! 
  for (current_unique_sequence in names(v_unique_freqs)){
    output <- output + sum(v_unique_freqs[current_unique_sequence]*pwdiff_with_others(the_sequence = current_unique_sequence,lst_unique_sequences = names(v_unique_freqs)[which(names(v_unique_freqs)==current_unique_sequence):length(names(v_unique_freqs))]))
  }
  return(output)
}  

#Tajima's D with resampling of samples from a certain time period
get_time_period_Tajima_D_with_resampling <- function(the_time_period,n,k,label_lineage){
  v_consensus_seq_samples_sequenced_at_this_time_period <- df_consensus_seq[intersect(df_metadata_samples[(as.Date(df_metadata_samples$date)>=df_time_periods$start[the_time_period])&(as.Date(df_metadata_samples$date)<=df_time_periods$stop[the_time_period]),"strain"],rownames(df_consensus_seq)),"Consensus_seq"]
  if ((length(v_consensus_seq_samples_sequenced_at_this_time_period)==0)){
    return(data.frame(time_period=the_time_period,Tajima_D=NA,nb_cases=get_time_period_nb_cases(the_time_period),start_time_period=as.Date(df_time_periods[df_time_periods$time_period==the_time_period,"start"]),num_resampling=NA,the_lineage=label_lineage,stringsAsFactors=FALSE))
  }else if (n>=length(v_consensus_seq_samples_sequenced_at_this_time_period)){
    #print(length(v_consensus_seq_samples_sequenced_at_this_time_period))
    warning("Sample size for the period ",the_time_period," is too small. Thus, we assigned it a missing Tajima's D value!")
    return(data.frame(time_period=the_time_period,Tajima_D=NA,nb_cases=get_time_period_nb_cases(the_time_period),start_time_period=as.Date(df_time_periods[df_time_periods$time_period==the_time_period,"start"]),num_resampling=NA,the_lineage=label_lineage,stringsAsFactors=FALSE))
  }else if ((n<=0)||(k<=0)){
    stop("Re-sampling size and number of resamplings should be positive integers!")
  }else{
    df_downsamples_Taj_D <-  NULL
    for (i in 1:k){
      v_current_resampling_consensus_seq <- sample(x = v_consensus_seq_samples_sequenced_at_this_time_period,size = n,replace = FALSE)
      if (is.na(v_current_resampling_consensus_seq[1])){
        print(the_date)
      }
      nb_copy_genome <- n
      #calculate number of pairwise differences without considering "N" (ambiguous consensus call)
      nb_pwdiffs_current_resampling <- calculate_nb_pwd(v_current_resampling_consensus_seq)
      #calculate number of segregating sites without considering "N" (ambiguous consensus call)
      nb_segreg_sites_current_resampling <- sum(vapply(X = 1:(max(nchar(df_consensus_seq$Consensus_seq),na.rm=T)),FUN = function(the_indx) return(length(table(substr(x = v_current_resampling_consensus_seq,start = the_indx,stop = the_indx))[names(table(substr(x = v_current_resampling_consensus_seq,start = the_indx,stop = the_indx)))!="N"])>1),FUN.VALUE = TRUE))
      #parameters to calculate expected sqrt_variance
      a1_current <- sum((1:(nb_copy_genome-1))^-1)
      a2_current <- sum((1:(nb_copy_genome-1))^-2)
      b1_current <- (nb_copy_genome+1)/(3*(nb_copy_genome-1))
      b2_current <- (2*((nb_copy_genome^2)+nb_copy_genome+3))/((9*nb_copy_genome)*(nb_copy_genome-1))
      c1_current <- b1_current - (1/a1_current)
      c2_current <- b2_current - ((nb_copy_genome+2)/(a1_current*nb_copy_genome)) + (a2_current/(a1_current^2))
      e1_current <- c1_current/a1_current
      e2_current <- c2_current/((a1_current^2)+a2_current)
      
      #Find S , find a1_current, calculate expected sqrt_variance with formula form Tajima (1989) and calculate Tajima's D and Ne_S_Taj according to it
      sqrt_expected_variance_current <- sqrt((e1_current*nb_segreg_sites_current_resampling)+((e2_current*nb_segreg_sites_current_resampling)*(nb_segreg_sites_current_resampling-1)))
      
      #Thetas and Tajima's D
      Theta_pi_current <- nb_pwdiffs_current_resampling/(choose(k = 2,n = nb_copy_genome))
      Theta_w_current <- nb_segreg_sites_current_resampling/(a1_current)
      df_downsamples_Taj_D <- rbind(df_downsamples_Taj_D,data.frame(time_period=the_time_period,Tajima_D=(((Theta_pi_current - Theta_w_current))/sqrt_expected_variance_current),nb_cases=get_time_period_nb_cases(the_time_period),start_time_period=as.Date(df_time_periods[df_time_periods$time_period==the_time_period,"start"]),num_resampling=i,the_lineage=label_lineage,stringsAsFactors=FALSE))
      print(paste0(i," iterations out of ",k," done for period ",the_time_period,"!"))
    }
  }
  print(paste0("Tajima's D analysis with resampling is done for period #",the_time_period))
  print("*****************************************************************************")
  return(df_downsamples_Taj_D)
}

#Resamplings' Tajima's D
v_time_periods <- sort(unique(df_time_periods$time_period))
nb_time_periods <- length(v_time_periods)
lst_splits <- split(1:nb_time_periods, ceiling(seq_along(1:nb_time_periods)/(nb_time_periods/nb_cores)))
the_f_parallel <- function(i_cl){
  the_vec<- lst_splits[[i_cl]]
  i_time_period <- 1
  current_time_period_df_Taj_D_from_all_resamplings <- NULL
  for (current_time_period in v_time_periods[the_vec]){
    current_time_period_df_Taj_D_from_all_resamplings <- rbind(current_time_period_df_Taj_D_from_all_resamplings,get_time_period_Tajima_D_with_resampling(the_time_period = current_time_period,n = 20,k = 99,label_lineage="All lineages"))
    print(paste0("Core ",i_cl,": ",i_time_period," iterations done out of ",length(v_time_periods[the_vec]),"!"))
    i_time_period <- i_time_period + 1
  }
  return(current_time_period_df_Taj_D_from_all_resamplings)
}

cl <- makeCluster(nb_cores,outfile=paste0(output_workspace,"LOG_resamplings_Tajima_D.txt"))
registerDoParallel(cl)
df_time_period_Taj_D_with_resamplings <- foreach(i_cl = 1:nb_cores, .combine = rbind, .packages=c("ggplot2","seqinr","grid","RColorBrewer","randomcoloR","gplots","RColorBrewer","tidyr","infotheo","parallel","foreach","doParallel"))  %dopar% the_f_parallel(i_cl)
stopCluster(cl)

ggplot(data = df_time_period_Taj_D_with_resamplings,mapping = aes(x=as.Date(start_time_period),y=Tajima_D,group=as.factor(start_time_period))) + geom_boxplot()  + ylab("Tajima's D")+ xlab(paste0("Time")) + theme_classic() + theme(title =  element_text(size=12),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) +scale_x_date(limits = c(as.Date(min_date),as.Date(max_date)),breaks = seq(as.Date(min_date),as.Date(max_date),time_period_length),date_labels = ("%B %d"))
ggsave(filename = paste0(time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.png"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200)
ggsave(filename = paste0(time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.svg"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200,device=svg)
ggsave(filename = paste0(time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.pdf"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200,device=cairo_pdf)

df_time_periods$nb_sequences <- unname(vapply(X = 1:nrow(df_time_periods),FUN = function(i) length(unique(subset(df_metadata_samples,((as.Date(date)>=df_time_periods$start[i])&(as.Date(date)<=df_time_periods$stop[i])))$strain)),FUN.VALUE=c(0)))
df_unique_Taj_D_vs_nb_cases <- df_time_period_Taj_D_with_resamplings#aggregate(df_time_period_Taj_D_with_resamplings$Tajima_D,by=list(start_time_period=df_time_period_Taj_D_with_resamplings$start_time_period,nb_cases=df_time_period_Taj_D_with_resamplings$nb_cases),FUN=function(x) median(x,na.rm=T))
df_unique_Taj_D_vs_nb_cases$nb_sequences <- unname(vapply(X = df_unique_Taj_D_vs_nb_cases$start_time_period,FUN = function(x) df_time_periods$nb_sequences[df_time_periods$start==x],FUN.VALUE = c(0)))
ggplotRegression(fit = lmp(formula = Tajima_D~nb_cases,data = df_unique_Taj_D_vs_nb_cases,Iter=99999,center = FALSE),ggsave_path = output_workspace,the_filename = paste0("Correlation_",time_period_length,"days_Taj_D_with_resampling_vs_nb_cases_Qc_first_wave.png"),xlabl = paste0("Number of confirmed cases per time period (",time_period_length," days)"),ylabl = "Tajima's D")  
ggplotRegression(fit = lmp(formula = Tajima_D~nb_sequences,data = df_unique_Taj_D_vs_nb_cases,Iter=99999,center = FALSE),ggsave_path = output_workspace,the_filename = paste0("Correlation_",time_period_length,"days_Taj_D_with_resampling_vs_nb_sequences_Qc_first_wave.png"),xlabl = paste0("Number of sequenced samples per time period (",time_period_length," days)"),ylabl = "Tajima's D")  


#end_time <- Sys.time()
toc()



###########################################################################################################################
######################## Lineage-specific Tajima's D #####################################################################

#start_time <- Sys.time()
tic()

get_Taj_D_for_specific_pango_lineage <- function(the_pango_lineage){
  #create dataframe with samples consensus seq
  df_fasta_consensus_seq <- read.csv2(file = paste0(output_workspace,"testdataset250.fasta"),sep = ",",header = F,stringsAsFactors = FALSE)
  df_consensus_seq <- data.frame(Sample=unname(vapply(X = df_fasta_consensus_seq[which((1:nrow(df_fasta_consensus_seq))%%2==1),1],FUN= function(x) substr(x,2,nchar(x)),FUN.VALUE = c(""))),Consensus_seq=df_fasta_consensus_seq[which((1:nrow(df_fasta_consensus_seq))%%2==0),1],stringsAsFactors = F)
  rownames(df_consensus_seq) <- df_consensus_seq$Sample
  
  #import metadata
  df_metadata_samples <- read.csv2(file = paste0(output_workspace,"testdataset250_metadata.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
  df_metadata_samples$X <- NULL
  rownames(df_metadata_samples) <- df_metadata_samples$strain
  df_metadata_samples <- subset(df_metadata_samples,cladePang==the_pango_lineage)
  
  #Only keep consensus sequences for which we have metadata
  df_consensus_seq <- df_consensus_seq[rownames(df_metadata_samples),]
  
  # #Qc first wave confirmed cases (https://www.inspq.qc.ca/covid-19/donnees, INSPQ, 2020)
  # df_confirmed_cases_QC <- read.csv2(file = paste0(output_workspace,"Qc_nb_of_confirmed_cases.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
  # names(df_confirmed_cases_QC) <- c("date","from_epi_link","from_lab")
  # df_confirmed_cases_QC$total_nb_cases <- df_confirmed_cases_QC$from_epi_link+df_confirmed_cases_QC$from_lab
  # rownames(df_confirmed_cases_QC) <- df_confirmed_cases_QC$date
  # df_confirmed_cases_QC <- df_confirmed_cases_QC[((df_confirmed_cases_QC$date<max(as.Date(df_metadata_samples$date)))&(df_confirmed_cases_QC$date>min(as.Date(df_metadata_samples$date)))),]
  # 
  time_period_length <- 14 #number of days
  nb_time_periods <- ceiling(as.numeric(as.Date(max_date)-as.Date(min_date))/time_period_length)
  df_time_periods <- data.frame(time_period=1:nb_time_periods,start=as.Date(min_date)+(time_period_length*(0:(nb_time_periods-1))),stop=(as.Date(min_date)+(time_period_length-1))+(time_period_length*(0:(nb_time_periods-1))),Tajima_D=NA,stringsAsFactors = FALSE)
  #function for plotting linear model
  ggplotRegression <- function (fit,ggsave_path,the_filename,xlabl=NA,ylabl=NA) {
    library(ggplot2)
    bool_gg_save <- TRUE
    if(is.na(xlabl)){
      xlabl <- names(fit$model)[2]
    }
    if(is.na(ylabl)){
      ylabl <- names(fit$model)[1]
    }
    adj_r_sq <- formatC(summary(fit)$adj.r.squared, format = "e", digits = 3)
    slope <-formatC(summary(fit)$coefficients[,1][2], format = "e", digits = 3)
    p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=formatC(summary(fit)$coefficients[,3][2], format = "e", digits = 3),no=formatC(summary(fit)$coefficients[,2][2], format = "e", digits = 3)) 
    tryCatch(expr = {ggplot(fit$model, aes_string(x = names(fit$model)[2], y = names(fit$model)[1])) +
        geom_point() +
        stat_smooth(method = "lm", col = "red") +
        xlab(xlabl)+
        ylab(ylabl)+
        labs(title = paste("Adj R2 = ",adj_r_sq,
                           " Slope =",slope,
                           " P =",p_val))+ theme(plot.title=element_text(hjust=0,size=12))},error=function(e) bool_gg_save <- FALSE)
    
    if (bool_gg_save){
      ggsave(filename = the_filename, path=ggsave_path, width = 15, height = 10, units = "cm")
    }else{
      print(paste0(the_filename, "won't be created because of it is irrelevant for gene in path ", ggsave_path))
    }
    #return result as the real float numbers
    adj_r_sq <- unname(summary(fit)$adj.r.squared)
    slope <-unname(summary(fit)$coefficients[,1][2])
    p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = unname(summary(fit)$coefficients[,3][2])),no=summary(fit)$coefficients[,2][2])
    return(list(adj_r_sq_current_lm = adj_r_sq,slope_current_lm = slope,p_val_current_lm=p_val))
  }
  
  
  ggplotRegression_export_eps <- function (fit,ggsave_path,the_filename,xlabl=NA,ylabl=NA) {
    library(ggplot2)
    bool_gg_save <- TRUE
    if(is.na(xlabl)){
      xlabl <- names(fit$model)[2]
    }
    if(is.na(ylabl)){
      ylabl <- names(fit$model)[1]
    }
    adj_r_sq <- formatC(summary(fit)$adj.r.squared, format = "e", digits = 3)
    slope <-formatC(summary(fit)$coefficients[,1][2], format = "e", digits = 3)
    p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = formatC(unname(summary(fit)$coefficients[,3][2]), format = "e", digits = 3)),no=ifelse(test = unname(summary(fit)$coefficients[,4][2])<(2e-16),yes = "<2e-16",no = formatC(unname(summary(fit)$coefficients[,4][2]), format = "e", digits = 3)))
    tryCatch(expr = {ggplot(fit$model, aes_string(x = names(fit$model)[2], y = names(fit$model)[1])) +
        geom_point() +
        stat_smooth(method = "lm", col = "red") +
        xlab(xlabl)+
        ylab(ylabl)+
        labs(title = paste("Adj R2 = ",adj_r_sq,
                           " Slope =",slope,
                           " P =",p_val))+ theme(plot.title=element_text(hjust=0,size=12))},error=function(e) bool_gg_save <- FALSE)
    
    if (bool_gg_save){
      ggsave(filename = the_filename, path=ggsave_path, width = 15, height = 10, units = "cm", device = cairo_ps)
    }else{
      print(paste0(the_filename, "won't be created because of it is irrelevant for gene in path ", ggsave_path))
    }
    #return result as the real float numbers
    adj_r_sq <- unname(summary(fit)$adj.r.squared)
    slope <-unname(summary(fit)$coefficients[,1][2])
    p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = unname(summary(fit)$coefficients[,3][2])),no=ifelse(test = unname(summary(fit)$coefficients[,4][2])<(2e-16),yes = "<2e-16",no = unname(summary(fit)$coefficients[,4][2])))
    return(list(adj_r_sq_current_lm = adj_r_sq,slope_current_lm = slope,p_val_current_lm=p_val))
  }
  
  #function to get the number of cases detected during a certain time period
  get_time_period_nb_cases <- function(the_time_period){
    nb_cases_current_time_period <- sum(df_confirmed_cases_QC[(as.Date(df_confirmed_cases_QC$date)>=df_time_periods$start[the_time_period])&(as.Date(df_confirmed_cases_QC$date)<=df_time_periods$stop[the_time_period]),"total_nb_cases"])
    
    return(nb_cases_current_time_period)
  }
  
  #create a function that does all possible pariwise COMPARISONS between a set of unique sequences 
  #THE FUNCTION TAKES INTO ACCOUNT THE PRESENCE OF AMBIGUOUS CONSENSUS CALLS ("N")
  #Execution time is O(n^2)
  calculate_nb_pwd <- function(v_seqs){
    output <- 0 #initialize the variable that will contain the number of pairwise differences in single nucleotide sites
    pwdiff_with_others<- function(the_sequence,lst_unique_sequences){
      if (any(duplicated(lst_unique_sequences))){
        stop("There are doublons in the list of unique sequences.  Retry!")
      }
      result<-rep(NA,length(lst_unique_sequences))
      ind_res_list<-1
      for (current_diff_sequence in lst_unique_sequences){
        current_result<-0
        for (i in 1:nchar(v_seqs[1])){
          if ((substr(x = the_sequence,i,i)!=substr(x = current_diff_sequence,i,i))&(substr(x = the_sequence,i,i)!="N")&("N"!=substr(x = current_diff_sequence,i,i))){
            current_result <- current_result +1
          }
        }
        result[ind_res_list] <- current_result
        ind_res_list <- ind_res_list + 1
      }
      return(result)
    }
    v_unique_freqs <- list(table(v_seqs))[[1]]
    
    #comparisons are not duplicated here! 
    for (current_unique_sequence in names(v_unique_freqs)){
      output <- output + sum(v_unique_freqs[current_unique_sequence]*pwdiff_with_others(the_sequence = current_unique_sequence,lst_unique_sequences = names(v_unique_freqs)[which(names(v_unique_freqs)==current_unique_sequence):length(names(v_unique_freqs))]))
    }
    return(output)
  }  
  #Tajima's D with resampling of samples from a certain time period
  get_time_period_Tajima_D_with_resampling <- function(the_time_period,n,k,label_lineage){
    v_consensus_seq_samples_sequenced_at_this_time_period <- df_consensus_seq[intersect(df_metadata_samples[(as.Date(df_metadata_samples$date)>=df_time_periods$start[the_time_period])&(as.Date(df_metadata_samples$date)<=df_time_periods$stop[the_time_period]),"strain"],rownames(df_consensus_seq)),"Consensus_seq"]
    if ((length(v_consensus_seq_samples_sequenced_at_this_time_period)==0)){
      return(data.frame(time_period=the_time_period,Tajima_D=NA,nb_cases=get_time_period_nb_cases(the_time_period),start_time_period=as.Date(df_time_periods[df_time_periods$time_period==the_time_period,"start"]),num_resampling=NA,the_lineage=label_lineage,stringsAsFactors=FALSE))
    }else if (n>=length(v_consensus_seq_samples_sequenced_at_this_time_period)){
      #print(length(v_consensus_seq_samples_sequenced_at_this_time_period))
      warning("Sample size for the period ",the_time_period," is too small. Thus, we assigned it a missing Tajima's D value!")
      return(data.frame(time_period=the_time_period,Tajima_D=NA,nb_cases=get_time_period_nb_cases(the_time_period),start_time_period=as.Date(df_time_periods[df_time_periods$time_period==the_time_period,"start"]),num_resampling=NA,the_lineage=label_lineage,stringsAsFactors=FALSE))
    }else if ((n<=0)||(k<=0)){
      stop("Re-sampling size and number of resamplings should be positive integers!")
    }else{
      df_downsamples_Taj_D <-  NULL
      for (i in 1:k){
        v_current_resampling_consensus_seq <- sample(x = v_consensus_seq_samples_sequenced_at_this_time_period,size = n,replace = FALSE)
        if (is.na(v_current_resampling_consensus_seq[1])){
          print(the_date)
        }
        nb_copy_genome <- n
        #calculate number of pairwise differences without considering "N" (ambiguous consensus call)
        nb_pwdiffs_current_resampling <- calculate_nb_pwd(v_current_resampling_consensus_seq)
        #calculate number of segregating sites without considering "N" (ambiguous consensus call)
        nb_segreg_sites_current_resampling <- sum(vapply(X = 1:(max(nchar(df_consensus_seq$Consensus_seq),na.rm=T)),FUN = function(the_indx) return(length(table(substr(x = v_current_resampling_consensus_seq,start = the_indx,stop = the_indx))[names(table(substr(x = v_current_resampling_consensus_seq,start = the_indx,stop = the_indx)))!="N"])>1),FUN.VALUE = TRUE))
        #parameters to calculate expected sqrt_variance
        a1_current <- sum((1:(nb_copy_genome-1))^-1)
        a2_current <- sum((1:(nb_copy_genome-1))^-2)
        b1_current <- (nb_copy_genome+1)/(3*(nb_copy_genome-1))
        b2_current <- (2*((nb_copy_genome^2)+nb_copy_genome+3))/((9*nb_copy_genome)*(nb_copy_genome-1))
        c1_current <- b1_current - (1/a1_current)
        c2_current <- b2_current - ((nb_copy_genome+2)/(a1_current*nb_copy_genome)) + (a2_current/(a1_current^2))
        e1_current <- c1_current/a1_current
        e2_current <- c2_current/((a1_current^2)+a2_current)
        
        #Find S , find a1_current, calculate expected sqrt_variance with formula form Tajima (1989) and calculate Tajima's D and Ne_S_Taj according to it
        sqrt_expected_variance_current <- sqrt((e1_current*nb_segreg_sites_current_resampling)+((e2_current*nb_segreg_sites_current_resampling)*(nb_segreg_sites_current_resampling-1)))
        
        #Thetas and Tajima's D
        Theta_pi_current <- nb_pwdiffs_current_resampling/(choose(k = 2,n = nb_copy_genome))
        Theta_w_current <- nb_segreg_sites_current_resampling/(a1_current)
        df_downsamples_Taj_D <- rbind(df_downsamples_Taj_D,data.frame(time_period=the_time_period,Tajima_D=(((Theta_pi_current - Theta_w_current))/sqrt_expected_variance_current),nb_cases=get_time_period_nb_cases(the_time_period),start_time_period=as.Date(df_time_periods[df_time_periods$time_period==the_time_period,"start"]),num_resampling=i,the_lineage=label_lineage,stringsAsFactors=FALSE))
        print(paste0(i," iterations out of ",k," done for period ",the_time_period,"!"))
      }
    }
    print(paste0("Tajima's D analysis with resampling is done for period #",the_time_period))
    print("*****************************************************************************")
    return(df_downsamples_Taj_D)
  }
  
  #Resamplings' Tajima's D
  v_time_periods <- sort(unique(df_time_periods$time_period))
  nb_time_periods <- length(v_time_periods)
  lst_splits <- split(1:nb_time_periods, ceiling(seq_along(1:nb_time_periods)/(nb_time_periods/nb_cores)))
  the_f_parallel <- function(i_cl){
    the_vec<- lst_splits[[i_cl]]
    i_time_period <- 1
    current_time_period_df_Taj_D_from_all_resamplings <- NULL
    for (current_time_period in v_time_periods[the_vec]){
      current_time_period_df_Taj_D_from_all_resamplings <- rbind(current_time_period_df_Taj_D_from_all_resamplings,get_time_period_Tajima_D_with_resampling(the_time_period = current_time_period,n = 20,k = 99,label_lineage = the_pango_lineage))
      print(paste0("Core ",i_cl,": ",i_time_period," iterations done out of ",length(v_time_periods[the_vec]),"!"))
      i_time_period <- i_time_period + 1
    }
    return(current_time_period_df_Taj_D_from_all_resamplings)
  }
  cl <- makeCluster(nb_cores,outfile=paste0(output_workspace,"LOG_resamplings_Tajima_D_",the_pango_lineage,".txt"))
  registerDoParallel(cl)
  df_time_period_Taj_D_with_resamplings <- foreach(i_cl = 1:nb_cores, .combine = rbind, .packages=c("ggplot2","seqinr","grid","RColorBrewer","randomcoloR","gplots","RColorBrewer","tidyr","infotheo","parallel","foreach","doParallel"))  %dopar% the_f_parallel(i_cl)
  stopCluster(cl)
  
  ggplot(data = df_time_period_Taj_D_with_resamplings,mapping = aes(x=as.Date(start_time_period),y=Tajima_D,group=as.factor(start_time_period))) + geom_boxplot()  + ylab("Tajima's D")+ xlab(paste0("Time")) + theme_classic() + theme(title =  element_text(size=12),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12))+scale_x_date(limits = c(as.Date(min_date),as.Date(max_date)),breaks = seq(as.Date(min_date),as.Date(max_date),time_period_length),date_labels = ("%B %d"))
  ggsave(filename = paste0(the_pango_lineage,"_",time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.png"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200)
  #ggsave(filename = paste0(the_pango_lineage,"_",time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.eps"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200,device=cairo_ps)
  write.table(x = df_time_period_Taj_D_with_resamplings,file = paste0(output_workspace,"df_time_period_Taj_D_with_resamplings_lineage_",the_pango_lineage,".csv"),row.names = F,col.names = T,sep=",")
  ggplotRegression(fit = lmp(formula = Tajima_D~nb_cases,data = df_time_period_Taj_D_with_resamplings,Iter=99999,center = FALSE),ggsave_path = output_workspace,the_filename = paste0(the_pango_lineage,"_","Correlation_",time_period_length,"days_Taj_D_with_resampling_vs_nb_cases_Qc_first_wave.png"),xlabl = paste0("Number of confirmed cases per time period (",time_period_length," days)"),ylabl = "Tajima's D")  
  return(df_time_period_Taj_D_with_resamplings)
}

df_time_period_Taj_D_with_resamplings <- rbind(df_time_period_Taj_D_with_resamplings,get_Taj_D_for_specific_pango_lineage(the_pango_lineage = "B.1"),get_Taj_D_for_specific_pango_lineage(the_pango_lineage = "B.1.147"),get_Taj_D_for_specific_pango_lineage(the_pango_lineage = "B.1.1.176"),get_Taj_D_for_specific_pango_lineage(the_pango_lineage = "B.1.5"),get_Taj_D_for_specific_pango_lineage(the_pango_lineage = "B.1.350"),get_Taj_D_for_specific_pango_lineage(the_pango_lineage = "B.1.1"),get_Taj_D_for_specific_pango_lineage(the_pango_lineage = "B.1.3"))
df_time_period_Taj_D_with_resamplings$start_time_period_formatted <- format(df_time_period_Taj_D_with_resamplings$start_time_period,"%B %d")
ggplot(data = df_time_period_Taj_D_with_resamplings) + geom_boxplot(aes(x=factor(start_time_period_formatted,levels=format(sort(unique(df_time_period_Taj_D_with_resamplings$start_time_period)),"%B %d")),y=Tajima_D,fill=factor(the_lineage,levels=c("A","A.1","A.2.2","A.3","B","B.1","B.1.1","B.1.10","B.1.1.176","B.1.114","B.1.128","B.1.147","B.1.183","B.1.255","B.1.265","B.1.3","B.1.3.2","B.1.314","B.1.347","B.1.350","B.1.356","B.1.5","B.1.98","B.39","B.4","B.40","All lineages")) ))  + ylab("Tajima's D")+ xlab(paste0("Time")) + theme_classic() + theme(title =  element_text(size=12),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12))  +labs(fill="Lineage") #+ scale_fill_manual(values= c("All lineages"="black","B.1"="red","B.1.1"="orange","B.1.1.176"="darkseagreen1","B.1.147"="springgreen4","B.1.3"="deepskyblue","B.1.350"="blueviolet","B.1.5"="brown")) #+scale_x_date(limits = c(as.Date(min_date),as.Date(max_date)),breaks = seq(as.Date(min_date),as.Date(max_date),time_period_length),date_labels = ("%B %d"))
ggsave(filename = paste0("Lineage-specific_and_overall_",time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.png"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200)
ggsave(filename = paste0("Lineage-specific_and_overall_",time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.svg"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200,device=svg)
ggsave(filename = paste0("Lineage-specific_and_overall_",time_period_length,"days_Taj_D_with_resampling_across_time_during_Qc_first_wave.pdf"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200,device=cairo_pdf)

write.table(x = df_time_period_Taj_D_with_resamplings,file = paste0(output_workspace,"df_time_period_Taj_D_with_resamplings_ALL.csv"),row.names = F,col.names = T,sep=",")

#dN/dS time series Qc 
#import reference fasta 
genome_refseq <- seqinr::getSequence(object = toupper(read.fasta(paste0(output_workspace,"MN908947_3.fasta"),seqtype = "DNA",as.string = TRUE,forceDNAtolower = FALSE)),as.string = TRUE)[[1]]

#build function that determines whether a mutation is synonymous or not 
translate_seq <- function(the_codon){
  if (is.na(the_codon)){
    return(NA)
  }else if (the_codon %in% c("TAA","TAG","TGA")){
    return("Stop")
  }else{
    return(seqinr::translate(seq = unlist(strsplit(the_codon,""))))
  }
}

#create a function that returns number of synonymous sites for a single position in the genome
calculate_nb_ss_position_in_genome <- function(the_position){
  the_orf <- find_ORF_of_mutation(the_position)
  if (is.na(the_orf)||(grepl(pattern = "UTR",x = the_orf,fixed = TRUE))){
    return(NA)
  }else{
    pos_in_codon <- ((the_position - v_start_orfs[the_orf] + 1)%%3)+(3*as.integer(((the_position - v_start_orfs[the_orf] + 1)%%3)==0))
    if (pos_in_codon==1){
      the_codon <- substr(x = genome_refseq,start = the_position,stop = the_position+2)
    }else if (pos_in_codon==2){
      the_codon <- substr(x = genome_refseq,start = the_position-1,stop = the_position+1)
    }else if (pos_in_codon==3){
      the_codon <- substr(x = genome_refseq,start = the_position-2,stop = the_position)
    }else{
      stop("Codon position must be between 1 and 3!!!")
    }
  }
  if (nchar(the_codon)!=3){
    stop("codon length should be 3!")
  }
  possible_single_site_mutated_codons <- rep("",3)
  num_mut_codon <-1
  for (pos_codon in pos_in_codon){
    if (substr(the_codon,start = pos_codon,stop=pos_codon)=="A"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
      
    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="T"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="C"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else{#G
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }
  }
  #count the number of synonymous mutations based on the genetic code
  nb_unique_syn_mut_codons <-0 #default initialization
  if (the_codon == "TTT") {
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTC"])
    
  } else if (the_codon == "TTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTT"])
    
  } else if (the_codon == "TTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTG","CTT","CTC","CTA","CTG")])
    
  } else if (the_codon == "TTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","CTT","CTC","CTA","CTG")])
    
  } else if (the_codon == "TCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCC","TCA","TCG","AGT","AGC")])
  } else if (the_codon == "TCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCG","AGT","AGC")])
    
  } else if (the_codon == "TCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCC","TCG","AGT","AGC")])
    
  } else if (the_codon == "TCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCC","AGT","AGC")])
    
  } else if (the_codon == "TAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAC")])
    
  } else if (the_codon == "TAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAT")])
    
  } else if (the_codon == "TGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGC")])
    
  } else if (the_codon == "TGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGT")])
    
  } else if (the_codon == "TGG"){
    nb_unique_syn_mut_codons <- 0
    
  } else if (the_codon == "CTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTC","CTA","CTG")])
    
  } else if (the_codon == "CTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTA","CTG")])
    
  } else if (the_codon == "CTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTG")])
    
  } else if (the_codon == "CTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTA")])
    
  } else if (the_codon == "CCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCC","CCA","CCG")])
    
  } else if (the_codon == "CCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCA","CCG")])
    
    
  } else if (the_codon == "CCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCG")])
    
  } else if (the_codon == "CCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCA")])
    
  } else if (the_codon == "CAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAC")])
    
  } else if (the_codon == "CAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAT")])
    
  } else if (the_codon == "CAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAG")])
    
  } else if (the_codon == "CAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAA")])
    
  } else if (the_codon == "CGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGC","CGA","CGG")])
    
  } else if (the_codon == "CGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGG")])
    
  } else if (the_codon == "CGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGC","CGG")])
    
  } else if (the_codon == "CGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGC")])
    
  } else if (the_codon == "ATT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATA")])
    
  } else if (the_codon == "ATC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATT","ATA")])
    
  } else if (the_codon == "ATA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATT")])
    
  } else if (the_codon == "ATG"){
    nb_unique_syn_mut_codons <- 0
    
  } else if (the_codon == "ACT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACC","ACA","ACG")])
    
    
  } else if (the_codon == "ACC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACA","ACG")])
    
  } else if (the_codon == "ACA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACG")])
    
    
  } else if (the_codon == "ACG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACA")])
    
  } else if (the_codon == "AAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAC")])
    
  } else if (the_codon == "AAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAT")])
    
  } else if (the_codon == "AAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAG")])
    
  } else if (the_codon == "AAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAA")])
    
  } else if (the_codon == "AGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGC","TCT","TCC","TCA","TCG")])
    
  } else if (the_codon == "AGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGT","TCT","TCC","TCA","TCG")])
    
  } else if (the_codon == "AGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGG")])
    
  } else if (the_codon == "AGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGA")])
    
  } else if (the_codon == "GTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTG")])
    
  } else if (the_codon == "GTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTT","GTA","GTG")])
    
  } else if (the_codon == "GTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTT","GTG")])
    
  } else if (the_codon == "GTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTT")])
    
  } else if (the_codon == "GCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCG")])
    
  } else if (the_codon == "GCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCT","GCA","GCG")])
    
  } else if (the_codon == "GCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCT","GCG")])
    
  } else if (the_codon == "GCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCT")])
    
  } else if (the_codon == "GAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAC")])
    
  } else if (the_codon == "GAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAT")])
    
  } else if (the_codon == "GAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAG")])
    
  } else if (the_codon == "GAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAA")])
    
  } else if (the_codon == "GGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGG")])
    
  } else if (the_codon == "GGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGT","GGA","GGG")])
    
  } else if (the_codon == "GGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGT","GGG")])
    
    
  } else if (the_codon == "GGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGT")])
  }
  return((nb_unique_syn_mut_codons/3))
}

#create a function that returns number of possible SINGLE-SITE synonymous mutations divided by 3 for a CODON
calculate_third_of_possible_ns_codon <- function(the_codon){
  the_codon <- toupper(the_codon)
  if (nchar(the_codon)!=3){
    stop("codon length should be 3!")
  }
  possible_single_site_mutated_codons <- rep("",9)
  num_mut_codon <-1
  for (pos_codon in 1:3){
    if (substr(the_codon,start = pos_codon,stop=pos_codon)=="A"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
      
    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="T"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="C"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else{#G
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }
  }
  #count the number of synonymous mutations based on the genetic code
  nb_unique_syn_mut_codons <-0 #default initialization
  if (the_codon == "TTT") {
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTC"])
    
  } else if (the_codon == "TTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTT"])
    
  } else if (the_codon == "TTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTG","CTT","CTC","CTA","CTG")])
    
  } else if (the_codon == "TTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","CTT","CTC","CTA","CTG")])
    
  } else if (the_codon == "TCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCC","TCA","TCG","AGT","AGC")])
  } else if (the_codon == "TCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCG","AGT","AGC")])
    
  } else if (the_codon == "TCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCC","TCG","AGT","AGC")])
    
  } else if (the_codon == "TCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCC","AGT","AGC")])
    
  } else if (the_codon == "TAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAC")])
    
  } else if (the_codon == "TAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAT")])
    
  } else if (the_codon == "TGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGC")])
    
  } else if (the_codon == "TGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGT")])
    
  } else if (the_codon == "TGG"){
    nb_unique_syn_mut_codons <- 0
    
  } else if (the_codon == "CTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTC","CTA","CTG")])
    
  } else if (the_codon == "CTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTA","CTG")])
    
  } else if (the_codon == "CTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTG")])
    
  } else if (the_codon == "CTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTA")])
    
  } else if (the_codon == "CCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCC","CCA","CCG")])
    
  } else if (the_codon == "CCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCA","CCG")])
    
    
  } else if (the_codon == "CCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCG")])
    
  } else if (the_codon == "CCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCA")])
    
  } else if (the_codon == "CAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAC")])
    
  } else if (the_codon == "CAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAT")])
    
  } else if (the_codon == "CAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAG")])
    
  } else if (the_codon == "CAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAA")])
    
  } else if (the_codon == "CGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGC","CGA","CGG")])
    
  } else if (the_codon == "CGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGG")])
    
  } else if (the_codon == "CGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGC","CGG")])
    
  } else if (the_codon == "CGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGC")])
    
  } else if (the_codon == "ATT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATA")])
    
  } else if (the_codon == "ATC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATT","ATA")])
    
  } else if (the_codon == "ATA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATT")])
    
  } else if (the_codon == "ATG"){
    nb_unique_syn_mut_codons <- 0
    
  } else if (the_codon == "ACT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACC","ACA","ACG")])
    
    
  } else if (the_codon == "ACC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACA","ACG")])
    
  } else if (the_codon == "ACA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACG")])
    
    
  } else if (the_codon == "ACG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACA")])
    
  } else if (the_codon == "AAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAC")])
    
  } else if (the_codon == "AAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAT")])
    
  } else if (the_codon == "AAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAG")])
    
  } else if (the_codon == "AAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAA")])
    
  } else if (the_codon == "AGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGC","TCT","TCC","TCA","TCG")])
    
  } else if (the_codon == "AGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGT","TCT","TCC","TCA","TCG")])
    
  } else if (the_codon == "AGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGG")])
    
  } else if (the_codon == "AGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGA")])
    
  } else if (the_codon == "GTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTG")])
    
  } else if (the_codon == "GTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTT","GTA","GTG")])
    
  } else if (the_codon == "GTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTT","GTG")])
    
  } else if (the_codon == "GTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTT")])
    
  } else if (the_codon == "GCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCG")])
    
  } else if (the_codon == "GCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCT","GCA","GCG")])
    
  } else if (the_codon == "GCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCT","GCG")])
    
  } else if (the_codon == "GCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCT")])
    
  } else if (the_codon == "GAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAC")])
    
  } else if (the_codon == "GAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAT")])
    
  } else if (the_codon == "GAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAG")])
    
  } else if (the_codon == "GAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAA")])
    
  } else if (the_codon == "GGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGG")])
    
  } else if (the_codon == "GGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGT","GGA","GGG")])
    
  } else if (the_codon == "GGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGT","GGG")])
    
    
  } else if (the_codon == "GGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGT")])
  }
  return((nb_unique_syn_mut_codons/3))
}

calculate_epitope_related_sites_nb_ss <- function(start_pos,end_pos){
  Nb_syn_sites_peptide <- 0
  for (pos_in_gene in seq(from =start_pos,to = end_pos,by = 3)){
    current_codon_gene <- substr(x = genome_refseq,start = pos_in_gene,stop=pos_in_gene+2)
    Nb_syn_sites_peptide <- Nb_syn_sites_peptide + calculate_third_of_possible_ns_codon(current_codon_gene)
  }
  return(Nb_syn_sites_peptide)
}

#Get list of genomic region and positions
v_orfs <- c("5'UTR", "orf1a", "orf1b", "S","ORF3a","ORF3b","ORF3c","E","M","ORF6","ORF7a", "ORF7b","ORF8", "N", "ORF10","3'UTR")
v_start_orfs <- c(1, 266, 13468, 21563, 25393, 25814, 25524,26245, 26523, 27202, 27394, 27756,27894, 28274, 29558, 29675)
names(v_start_orfs) <- v_orfs
v_end_orfs <- c(265, 13468, 21555, 25384, 26220, 25882, 25697, 26472, 27191, 27387, 27759, 27887,28259, 29533, 29674, 29903)
names(v_end_orfs) <- v_orfs
find_ORF_of_mutation <- function(the_site_position){
  indx <- which((v_start_orfs<=the_site_position)&(v_end_orfs>=the_site_position))[1]
  if (length(indx)==0){
    return(NA)
  }else{
    return(v_orfs[indx])
  }
}

v_genes_with_unique_product <- c(paste0("NSP",1:10),paste0("NSP",12:16), "S","ORF3a","ORF3b","ORF3c","E","M","ORF6","ORF7a", "ORF7b","ORF8", "N", "ORF10")
v_start_genes <- c(264+1,264+541,264+2455,264+8290,264+9790,264+10708,264+11578,264+11827,264+12421,264+12760,264+13176,264+15972,264+17775,264+19356,264+20394,21563, 25393, 25814, 25524, 26245, 26523, 27202, 27394, 27756, 27894, 28274, 29558)
names(v_start_genes) <- v_genes_with_unique_product
v_end_genes <- c(264+540,264+2454,264+8289,264+9789,264+10707,264+11577,264+11826,264+12420,264+12759,264+13176,264+15971,264+17774,264+19355,264+20393,264+21287,25384, 26220,25882, 25697, 26472, 27191, 27387, 27759, 27887, 28259, 29533, 29674)
names(v_end_genes) <- v_genes_with_unique_product
find_gene_of_mutation <- function(the_site_position){
  indx <- which((v_start_genes<=the_site_position)&(v_end_genes>=the_site_position))[1]
  if (length(indx)==0){
    return(NA)
  }else{
    return(v_genes_with_unique_product[indx])
  }
}
v_orfs_length <- v_end_orfs - v_start_orfs + 1 


calculate_dN_dS_metrics_of_sample <- function(the_sample_consensus_seq){
  if (nchar(the_sample_consensus_seq)!=nchar(genome_refseq)){
    return(NA)
  }
  v_lst_ORFs <- c("orf1a","orf1b","S","E","M","N")
  Nb_sm <- 0
  Nb_nsm <- 0
  Nb_ss <- 0
  Nb_nss <- 0 
  Nb_sites_considered <- 0
  for (current_ORF in v_lst_ORFs){
    for (current_pos_start_codon in seq(from=1,to=v_orfs_length[current_ORF]-2,by=3)){
      ref_codon <- substr(x = genome_refseq,start = current_pos_start_codon,stop = current_pos_start_codon+2)
      current_seq_codon <- substr(x = the_sample_consensus_seq,start = current_pos_start_codon,stop = current_pos_start_codon+2)
      #skip current codon if there is an ambiguous base "N" or if it's a stop codon or if ref_codon is the same as current_seq_codon
      if ((grepl(pattern = "N",x = current_seq_codon,fixed = T))||(translate_seq(the_codon = current_seq_codon)=="Stop")||(translate_seq(the_codon = ref_codon)=="Stop")||(ref_codon==current_seq_codon)){
        next()
      }else{
        if (translate_seq(the_codon = ref_codon)==translate_seq(the_codon = current_seq_codon)){#Synonymous mutation
          Nb_sm <- Nb_sm + 1
        }else{#Non-synonymous mutation
          Nb_nsm <- Nb_nsm + 1
        }
      }
      #add the number of synonymous sites in current codon to Nb_ss
      Nb_ss <- Nb_ss + (calculate_nb_ss_position_in_genome(the_position = v_start_orfs[current_ORF] + current_pos_start_codon - 1) + calculate_nb_ss_position_in_genome(the_position = v_start_orfs[current_ORF] + current_pos_start_codon - 1 + 1) + calculate_nb_ss_position_in_genome(the_position = v_start_orfs[current_ORF] + current_pos_start_codon - 1 + 2))
      Nb_sites_considered <- Nb_sites_considered + 3
    }
  }
  Nb_nss <- Nb_sites_considered - Nb_ss
  out_dN_dS <- ifelse(test = Nb_sm<1,yes = NA,no = ((Nb_nsm/Nb_nss)/(Nb_sm/Nb_ss)))
  return(out_dN_dS)
}

#dN/dS time series
df_time_periods_whole_genome_dN_dS <- data.frame(time_period=1:nb_time_periods,start=as.Date(min_date)+(time_period_length*(0:(nb_time_periods-1))),stop=(as.Date(min_date)+(time_period_length-1))+(time_period_length*(0:(nb_time_periods-1))),stringsAsFactors = FALSE)

df_individual_samples_seq_date_and_dN_dS <- unique(df_metadata_samples[,c("strain","date")])
df_individual_samples_seq_date_and_dN_dS$dN_dS <- NA
for (i in 1:nrow(df_individual_samples_seq_date_and_dN_dS)){
  df_individual_samples_seq_date_and_dN_dS$dN_dS[i] <- calculate_dN_dS_metrics_of_sample(the_sample_consensus_seq = subset(df_consensus_seq,Sample==df_individual_samples_seq_date_and_dN_dS$strain[i])$Consensus_seq[1])
  print(paste0(i," samples dN/dS calculated out of ",nrow(df_individual_samples_seq_date_and_dN_dS),"! Whole-genome dN/dS of the current sample = ",df_individual_samples_seq_date_and_dN_dS$dN_dS[i]))
}
df_individual_samples_seq_date_and_dN_dS$time_period <- unname(vapply(X = df_individual_samples_seq_date_and_dN_dS$date,FUN = function(x) subset(df_time_periods_whole_genome_dN_dS,(x>=start)&(x<=stop))$time_period,FUN.VALUE = c(0.0)))
df_individual_samples_seq_date_and_dN_dS$start_time_period <- unname(vapply(X = df_individual_samples_seq_date_and_dN_dS$time_period,FUN = function(x) as.character(subset(df_time_periods_whole_genome_dN_dS,time_period==x)$start),FUN.VALUE = c("")))
df_individual_samples_seq_date_and_dN_dS$end_time_period <- unname(vapply(X = df_individual_samples_seq_date_and_dN_dS$time_period,FUN = function(x) as.character(subset(df_time_periods_whole_genome_dN_dS,time_period==x)$stop),FUN.VALUE = c("")))
df_individual_samples_seq_date_and_dN_dS$pangolin_lineage <- unname(vapply(X = df_individual_samples_seq_date_and_dN_dS$strain,FUN = function(x) subset(df_metadata_samples,strain==x)$cladePang,FUN.VALUE = c("")))
#dN/dS time series
ggplot(data = df_individual_samples_seq_date_and_dN_dS,mapping = aes(x=as.Date(start_time_period),y=dN_dS,group=as.factor(start_time_period))) + geom_boxplot()  + ylab("dN/dS")+ xlab(paste0("Time")) + theme_classic() + theme(title =  element_text(size=12),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + scale_y_continuous(breaks = seq(0,max(df_individual_samples_seq_date_and_dN_dS$dN_dS,na.rm=T),0.1),limits = c(0,max(df_individual_samples_seq_date_and_dN_dS$dN_dS,na.rm=T))) + scale_x_date(limits = c(as.Date(min_date),as.Date(max_date)),breaks = seq(as.Date(min_date),as.Date(max_date),time_period_length),date_labels = ("%B %d"))
ggsave(filename = paste0(time_period_length,"days_dN_dS_with_resampling_across_time_during_Qc_first_wave.png"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200)
#ggsave(filename = paste0(time_period_length,"days_dN_dS_with_resampling_across_time_during_Qc_first_wave.eps"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200,device=cairo_ps)

ggplot(data = df_individual_samples_seq_date_and_dN_dS,mapping = aes(x=reorder(pangolin_lineage,-dN_dS,mean),y=dN_dS,group=pangolin_lineage)) + geom_boxplot()  + ylab("dN/dS")+ xlab(paste0("PANGOLIN lineage")) + theme_classic() + theme(title =  element_text(size=12),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + scale_y_continuous(breaks = seq(0,max(df_individual_samples_seq_date_and_dN_dS$dN_dS,na.rm=T),0.1),limits = c(0,max(df_individual_samples_seq_date_and_dN_dS$dN_dS,na.rm=T)))
ggsave(filename = paste0("Pangolin_ALL_lineages_dN_dS_Qc_first_wave.png"), path=output_workspace, width = 33, height = 15, units = "cm",dpi = 1200)

ggplot(data = subset(df_individual_samples_seq_date_and_dN_dS,pangolin_lineage%in%c("A","A.1","A.2.2","A.3","B","B.1","B.1.1","B.1.10","B.1.1.176","B.1.114","B.1.128","B.1.147","B.1.183","B.1.255","B.1.265","B.1.3","B.1.3.2","B.1.314","B.1.347","B.1.350","B.1.356","B.1.5","B.1.98","B.39","B.4","B.40")),mapping = aes(x=factor(pangolin_lineage,levels=c("A","A.1","A.2.2","A.3","B","B.1","B.1.1","B.1.10","B.1.1.176","B.1.114","B.1.128","B.1.147","B.1.183","B.1.255","B.1.265","B.1.3","B.1.3.2","B.1.314","B.1.347","B.1.350","B.1.356","B.1.5","B.1.98","B.39","B.4","B.40")),y=dN_dS,col=factor(pangolin_lineage,levels=c("A","A.1","A.2.2","A.3","B","B.1","B.1.1","B.1.10","B.1.1.176","B.1.114","B.1.128","B.1.147","B.1.183","B.1.255","B.1.265","B.1.3","B.1.3.2","B.1.314","B.1.347","B.1.350","B.1.356","B.1.5","B.1.98","B.39","B.4","B.40")))) + geom_boxplot()  + ylab("dN/dS")+ xlab(paste0("PANGOLIN lineage")) + theme_classic() + theme(title =  element_text(size=12),axis.text.x = element_text(angle = 90,vjust=0.5,hjust=1,size=10),axis.text.y = element_text(size=10),legend.position = "none") + scale_y_continuous(breaks = seq(0,max(df_individual_samples_seq_date_and_dN_dS$dN_dS,na.rm=T),0.1),limits = c(0,max(df_individual_samples_seq_date_and_dN_dS$dN_dS,na.rm=T))) + geom_hline(yintercept = 1,lty=2)
ggsave(filename = paste0("Fig4D_Pangolin_lineages_dN_dS_Qc_first_wave.png"), path=output_workspace, width = 20, height = 10, units = "cm",dpi = 1200)
ggsave(filename = paste0("Fig4D_Pangolin_lineages_dN_dS_Qc_first_wave.eps"), path=output_workspace, width = 20, height = 10, units = "cm",dpi = 1200,device=cairo_ps)
ggsave(filename = paste0("Fig4D_Pangolin_lineages_dN_dS_Qc_first_wave.pdf"), path=output_workspace, width = 20, height = 10, units = "cm",dpi = 1200,device=cairo_pdf)
write.table(x = df_individual_samples_seq_date_and_dN_dS,file = paste0(output_workspace,"Table_Data_Fig4D_Pangolin_lineages_dN_dS_Qc_first_wave.csv"),row.names = F,col.names = T,sep=",")


#Time code execution
#end_time <- Sys.time()
toc()
#paste0("Execution time: ",end_time - start_time,"!")

#Save R session
save.session(file = paste0(output_workspace,"Taj_D_and_dN_dS_Rsession_",gsub(pattern = ":",replacement = "_",x = gsub(pattern = " ",replacement = "_",x = date())),".Rda"))
