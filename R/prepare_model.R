# this script used to apply the country-specific urban growth model under future SSPs
# take an example of SSP2 ('middle of the road')


#' Prepare the ubran data for the citys2m model
#'
#' @param config_yml Full path with file name to the configuration YAML file
#' @importFrom yaml read_yaml
#' @importFrom dplyr select left_join
#' @export
prepare_model <- function(config_yml) {

  config <- read_yaml(config_yml)

  # load future of GDP data from SSP
  SSP_GDP <- read.csv(config$prep_model$ssp_gdp_file, stringsAsFactors = FALSE)
  # SSP_cntry <- SSP_GDP$cntry

  # load historical GDP data from world bank
  His_GDP <- read.csv(config$prep_model$hist_gdp_file, stringsAsFactors = FALSE)

  # sequence of years to evaluate
  yr_seq <- seq(config$general$start_year, config$general$through_year, config$general$year_interval)

  # Combine History and future
  SSP_GDP_his <- dplyr::left_join(SSP_GDP, His_GDP, by = c('cntry'='cntryCode')) %>%
    dplyr::select(cumGDP, paste0('y', yr_seq))

  SSP_GDP_cum <- t(apply(SSP_GDP_his, 1, cumsum))[,-1]

  # Load population
  SSP_POP <- read.csv(config$prep_model$population_file)[,-1]

  # Calcualte the per capitre GDP (GDP: billion; POP: million)
  SSP_PerGDP <- (SSP_GDP_cum*1000000000)/(SSP_POP*1000000)
  SSP_perGDP_log <- log10(SSP_PerGDP)

  # Load the derived model for each country
  paraTable <- read.csv(config$prep_model$global_model_file)

  # Loop to project the urban area
  SSP_Urban_list <- list()
  for (i in 1:nrow(paraTable)) {
    # *** load parameters
    a = paraTable[i, 'a']
    b = paraTable[i, 'b']
    c = paraTable[i, 'c']
    d = paraTable[i, 'd']

    x = SSP_perGDP_log[i, ]
    y = a/(1+exp(-b*(x-c)))+d

    # convert into km2
    y_perUrban = 10^y;  # m2/per
    y_Urban = (y_perUrban*SSP_POP[i, ]*1000000)/1000000  # km2

    # find out the maximum y_Urban
    index = which(y_Urban == max(y_Urban))
    y_Urban[index:length(y_Urban)] = max(y_Urban)

    # save results
    SSP_Urban_list[[i]]= y_Urban

  }

  SSP_Urban <- do.call(rbind, SSP_Urban_list)
  SSP_Urban <- cbind('y2010'=SSP_Urban[, 1], SSP_Urban[, -1]/SSP_Urban[, 1]) # convert to ratio

  # comparise as a table for output
  CntryID <- read.csv(config$prep_model$country_id_file, stringsAsFactors = FALSE) # read the country ID table
  cmbTable <- cbind('cntry'= SSP_GDP[,'cntry'], SSP_Urban, stringsAsFactors = FALSE) %>%
    dplyr::left_join(., CntryID, by = c('cntry'='ne_10m_adm')) %>%   #join the country ID
    dplyr::select(cntry, Code, paste0('y', yr_seq))

  write.csv(cmbTable, config$prep_model$output_urban_file, row.names=FALSE)
}
