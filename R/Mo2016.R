
#function - FD identification based on Mo & Lettenmeier (2015, 2016)

Mo2016 <- function(vtime, vprecipitation, vtemperature, vsoil_water,
                   vlatent_heat = NULL, vevap = NULL, flux_data = T){


  # allow direct input of actual evapotranspiration data
  if (flux_data){
    vevap <- actual_evap_day(vtime = vtime, vlatent_heat = vlatent_heat,
                              vtemperature = vtemperature)
    #remove negative values (condensation)
    vevap[vevap < 0] <- 0
  } else {vevap[vevap < 0] <- 0}

  #get dataa into list
  list_classification <- list(precipitation = data.frame(time = vtime,
                                                         value = vprecipitation),
                              temperature = data.frame(time = vtime,
                                                       value = vtemperature),
                              soil_water = data.frame(time = vtime,
                                                      value = vsoil_water),
                              actual_evap = data.frame(time = vtime,
                                                       value = vevap$eta))

  #get data from the list into pentads
  list_pentad <- NULL
  var_names <- c('precipitation', 'temperature','soil_water', 'actual_evap')
  for (i in var_names){
    list_pentad[[i]] <- f.pentad(vtime = list_classification[[i]]$time,
                                 vvalue = list_classification[[i]]$value)
  }

  pentad_series <- cbind(as.data.frame(list_pentad[[var_names[1]]][1]),
                         as.data.frame(list_pentad[[var_names[2]]][1])[,2],
                         as.data.frame(list_pentad[[var_names[3]]][1])[,2],
                         as.data.frame(list_pentad[[var_names[4]]][1])[,2])
  colnames(pentad_series) <- c('time',var_names)

  pentad_matrix <- list(precipitation = list_pentad[[var_names[1]]][2],
                        temperature = list_pentad[[var_names[2]]][2],
                        soil_water = list_pentad[[var_names[3]]][2],
                        actual_evap = list_pentad[[var_names[4]]][2])

  #get anomalies and perrcentiles
  pentad_statistics <- pentad_matrix
  pentad_statistics[['precipitation_anom']] <-
    t(apply(as.data.frame(pentad_matrix[['precipitation']]),1, f.anomaly))
  pentad_statistics[['precipitation_perc']] <-
    t(apply(as.data.frame(pentad_matrix[['precipitation']]),1, f.percentile))
  pentad_statistics[['temperature']] <-
    t(apply(as.data.frame(pentad_matrix[['temperature']]),1, f.anomaly))
  pentad_statistics[['soil_water']] <-
    t(apply(as.data.frame(pentad_matrix[['soil_water']]),1, f.percentile))
  pentad_statistics[['actual_evap']] <-
    t(apply(as.data.frame(pentad_matrix[['actual_evap']]), 1, f.anomaly))

  pentad_series_stat <- data.frame(time = pentad_series$time)
  pentad_series_stat$precipitation_anom <- c(pentad_statistics[['precipitation_anom']])
  pentad_series_stat$precipitation_perc <- c(pentad_statistics[['precipitation_perc']])
  pentad_series_stat$temperature <- c(pentad_statistics[['temperature']])
  pentad_series_stat$soil_water <- c(pentad_statistics[['soil_water']])
  pentad_series_stat$actual_evap <- c(pentad_statistics[['actual_evap']])


  ### Classification
  #Identify pentads under Heat Wave Flash Drought
  pentad_series_stat$HWFD <- (pentad_series_stat$precipitation_anom < 0)*
    (pentad_series_stat$temperature > 1)*
    (pentad_series_stat$soil_water < 40)*
    (pentad_series_stat$actual_evap > 0)

  #Identify pentads under Precipitation Deficit Flash Drought
  pentad_series_stat$PDFD <- (pentad_series_stat$precipitation_perc < 40)*
    (pentad_series_stat$temperature > 1)*
    (pentad_series_stat$actual_evap > 0)

  pentad_df <- data.frame(time = pentad_series_stat$time,
                          hwfd = pentad_series_stat$HWFD,
                          pdfd = pentad_series_stat$PDFD)


  ### Get separated events and durations for HWFD, PDFD, and Jointed
  #this stores the position of the last NA in the begining of the series of soil moisture
  lastNA <- min(which(!is.na(pentad_df$hwfd))) - 1

  #we remove temporarily the NA to performe the identification
  pentad_df$hwfd[1:lastNA] <- 0

  pentad_df$joint <- pentad_df$hwfd + pentad_df$pdfd
  pentad_df$joint[pentad_df$joint == 2] <- 1

  #initialise columns
  count_hwfd<-0
  count_pdfd<-0
  count_joint<-0
  pentad_df$event_hwfd <- 0
  pentad_df$event_pdfd <- 0
  pentad_df$event_joint <- 0
  pentad_df$dur_hwfd <- 0
  pentad_df$dur_pdfd <- 0
  pentad_df$dur_joint <- 0

  #run event identification
  for (i in 2:nrow(pentad_df)){
    #HWFD
    if(pentad_df$hwfd[i-1] == 0 & pentad_df$hwfd[i] == 1){
      count_hwfd = count_hwfd + 1
      pentad_df$event_hwfd[i] <- count_hwfd
      pentad_df$dur_hwfd[i] <- 1
    }
    if (pentad_df$hwfd[i-1] == 1 &pentad_df$hwfd[i] == 1){
      pentad_df$event_hwfd[i] <- count_hwfd
      pentad_df$dur_hwfd[i] <- pentad_df$dur_hwfd[i-1] + 1
    }
    #PDFD
    if (pentad_df$pdfd[i-1] == 0 & pentad_df$pdfd[i] == 1){
      count_pdfd = count_pdfd + 1
      pentad_df$event_pdfd[i] <- count_pdfd
      pentad_df$dur_pdfd[i] <- 1
    }
    if (pentad_df$pdfd[i-1] == 1 &pentad_df$pdfd[i] == 1){
      pentad_df$event_pdfd[i] <- count_pdfd
      pentad_df$dur_pdfd[i] <- pentad_df$dur_pdfd[i-1] + 1
    }

    #Joint
    if (pentad_df$pdfd[i-1] == 0 & pentad_df$pdfd[i] == 1){
      count_pdfd = count_pdfd + 1
      pentad_df$event_pdfd[i] <- count_pdfd
      pentad_df$dur_pdfd[i] <- 1
    }
    if (pentad_df$pdfd[i-1] == 1 &pentad_df$pdfd[i] == 1){
      pentad_df$event_pdfd[i] <- count_pdfd
      pentad_df$dur_pdfd[i] <- pentad_df$dur_pdfd[i-1] + 1
    }

    if (pentad_df$joint[i-1] == 0 & pentad_df$joint[i] == 1){
      count_joint = count_joint + 1
      pentad_df$event_joint[i] <- count_joint
      pentad_df$dur_joint[i] <- 1
    }
    if (pentad_df$joint[i-1] == 1 &pentad_df$joint[i] == 1){
      pentad_df$event_joint[i] <- count_joint
      pentad_df$dur_joint[i] <- pentad_df$dur_joint[i-1] + 1
    }

  }

  ## summary HWFD
  fd_summary_hwfd <- data.frame(event = unique(pentad_df$event_hwfd)[c(-1)])

  fd_summary_hwfd$start <- pentad_df  %>% dplyr::group_by(event_hwfd) %>%
    dplyr::summarise(x = min(.data[["time"]])) %>% .[,2] %>% unlist() %>%
    as.POSIXct(origin = "1970-01-01") %>% .[c(-1)]

  fd_summary_hwfd$duration <- pentad_df %>% dplyr::group_by(event_hwfd) %>%
    dplyr::summarise(x = max(.data[["dur_hwfd"]])) %>% .[,2] %>% unlist() %>% .[c(-1)]

  ## summary PDFD
  fd_summary_pdfd <- data.frame(event = unique(pentad_df$event_pdfd)[c(-1)])

  fd_summary_pdfd$start <- pentad_df  %>% dplyr::group_by(event_pdfd) %>%
    dplyr::summarise(x = min(.data[["time"]])) %>% .[,2] %>% unlist() %>%
    as.POSIXct(origin = "1970-01-01") %>% .[c(-1)]

  fd_summary_pdfd$duration <- pentad_df %>% dplyr::group_by(event_pdfd) %>%
    dplyr::summarise(x = max(.data[["dur_pdfd"]])) %>% .[,2] %>% unlist() %>% .[c(-1)]

  ## summary joint
  fd_summary_joint <- data.frame(event = unique(pentad_df$event_joint)[c(-1)])

  fd_summary_joint$start <- pentad_df  %>% dplyr::group_by(event_joint) %>%
    dplyr::summarise(x = min(.data[["time"]])) %>% .[,2] %>% unlist() %>%
    as.POSIXct(origin = "1970-01-01") %>% .[c(-1)]

  fd_summary_joint$duration <- pentad_df %>% dplyr::group_by(event_joint) %>%
    dplyr::summarise(x = max(.data[["dur_joint"]])) %>% .[,2] %>% unlist() %>% .[c(-1)]

  # create a master summary with all events
  fd_summary <- list(hwfd = fd_summary_hwfd, pdfd = fd_summary_pdfd,
                     joint = fd_summary_joint)

  # create complete dataframe with climate data, statistics and fd identification
  fd_data_series <- cbind(pentad_series, pentad_series_stat[,2:ncol(pentad_series_stat)]
                          , pentad_df[,c(4,5,6,7)])

  colnames(fd_data_series) <- c('time', 'precipitation', 'temperature', 'soil_water',
                                'actual_evap', 'prec_anom', 'prec_percentile',
                                'temp_anom','sw_anom','eta_anom', 'HWFD', 'PDFD',
                                'is.fd', 'event_hwfd','event_pdfd', 'event_joint')

  #set data into output
  output <- list('data_timeseries' = fd_data_series, 'FD_info' = fd_summary)

  return(output)
}

