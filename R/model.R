

#' Calculate the neighborhood using a window
#'
#' Calculate the neighborhood using a window
#'
#' @param urbanMap binary urban map (0-nonubran; 1-urban)
#' @param winSize window size
#' @return a raster of neighborhood value indicating urban probability
#' @importFrom raster focal mean
#' @export
urban_neighbor <- function(urbanMap, winSize){

  # create a matrix
  f <- matrix(1, nrow = winSize, ncol = winSize)
  f[(winSize*winSize+1)/2] <- 0

  urbanMap[is.na(urbanMap)] <- 0

  # apply the moving windows
  neiLayer <- focal(urbanMap, w=f, mean, na.rm=TRUE, pad=FALSE, padValue=NA)

  return(neiLayer)
}


#' Mirror the configuration file to the log file
#'
#' @param config Configuration object from YAML read_yaml
#' @param config_yml Full path with file name to the configuration YAML file
#' @importFrom logger log_info
log_config <- function(config, config_yml) {

  log_info("Configuration file:  {config_yml}")
  log_info("CONFIG:  general$start_year: {config$general$start_year}")
  log_info("CONFIG:  general$through_year: {config$general$through_year}")
  log_info("CONFIG:  general$year_interval: {config$general$year_interval}")
  log_info("CONFIG:  general$log_file: {config$general$log_file}")
  log_info("CONFIG:  prepare_model$ssp_gdp_file: {config$prepare_model$ssp_gdp_file}")
  log_info("CONFIG:  prepare_model$hist_gdp_file: {config$prepare_model$hist_gdp_file}")
  log_info("CONFIG:  prepare_model$population_file: {config$prepare_model$population_file}")
  log_info("CONFIG:  prepare_model$country_id_file: {config$prepare_model$country_id_file}")

  if (is.null(config$prepare_model$output_urban_file)) {
    log_info("CONFIG:  prepare_model$output_urban_file: NULL")
  } else {
    log_info("CONFIG:  prepare_model$output_urban_file: {config$prepare_model$output_urban_file}")
  }

  log_info("CONFIG:  model$spatial_var: {config$model$spatial_var}")

  if (is.null(config$model$urban_csv)) {
    log_info("CONFIG:  model$urban_csv: NULL")
  } else {
    log_info("CONFIG:  model$urban_csv: {config$model$urban_csv}")
  }

  log_info("CONFIG:  model$input_raster_dir: {config$model$input_raster_dir}")
  log_info("CONFIG:  model$output_raster_dir: {config$model$output_raster_dir}")
  log_info("End configuration logging.")

}


#' Run the citys2m model
#'
#' @param config_yml Full path with file name to the configuration YAML file
#' @param target_country_ids Optional.  List of country ids to evaluate.
#' @importFrom yaml read_yaml
#' @importFrom raster raster writeRaster intersect area union extract
#' @importFrom dplyr filter select arrange
#' @importFrom logger log_info log_appender appender_tee
#' @export
model <- function(config_yml, target_country_ids=NULL) {

  # set up logger
  log_file <- tempfile()

  # set logger to write to stdout and file
  log_appender(appender_tee(log_file))

  start_time <- Sys.time()
  log_info("Initializing model {start_time}")

  # read in configuration file
  config <- read_yaml(config_yml)

  # mirror config file to log file output
  log_config(config, config_yml)

  fileTag <- read.csv(config$model$spatial_var)

  # run prepare_model if no urban file is passed in the config file
  if (is.null(config$model$urban_csv)) {
    mat.cntryid <- prepare_model(config_obj = config, write_output = FALSE)
  } else {
    mat.cntryid <- read.csv(config$model$urban_csv)
  }

  if (!is.null(target_country_ids)) {
    mat.cntryid <- filter(mat.cntryid, Code %in% target_country_ids)
  }

  cntryid <- mat.cntryid[, 2]
  uqCntry = unique(cntryid); # regard one country as an integer

  for (cId in 1:length(uqCntry)){

    cntryId <- uqCntry[cId]  #regard one country as an integer

    log_info("Processing country id:  {cntryId}")

    # read the country boundary
    zone_file <- paste0(config$model$input_raster_dir, fileTag[1,1], '/', fileTag[1,2], '_', cntryId, '.tif')

    zoneLayer <- raster(zone_file) #regard one country as an integer
    zoneLayer[zoneLayer == 0] <- NA #remove the background area

    # add the land covers
    coverLayer <- raster(paste0(config$model$input_raster_dir, fileTag[2, 1], '/', fileTag[2, 2], '_', cntryId, '.tif'))

    # get the suitable layer
    suitLayer <- raster(paste0(config$model$input_raster_dir, fileTag[5, 1], '/', fileTag[5, 2], '_', cntryId, '.tif'))

    # get the urbanized areas
    urbanLayer <- raster(paste0(config$model$input_raster_dir, fileTag[4, 1], '/', fileTag[4, 2], '_', cntryId, '.tif'))

    # Load exclusion map
    # exclude the water area
    WatLayer <- coverLayer
    WatLayer[WatLayer == 0] <- NA  # assign NA for the water area
    WatLayer = as.logical(WatLayer)*as.logical(zoneLayer)

    # exclude the projection area
    PaLayer = raster(paste0(config$model$input_raster_dir, fileTag[3, 1], '/', fileTag[3, 2], '_', cntryId, '.tif'))
    PaLayer[PaLayer != 0] <- NA   # assign NA for the projection area
    PaLayer = as.logical(1-PaLayer)*as.logical(zoneLayer)

    # year sequence
    yList <- seq(config$general$start_year, config$general$through_year, config$general$year_interval)

    # Read the urban demand for each country
    urbanDemandRatio <- mat.cntryid %>%
      dplyr::filter(Code == uqCntry) %>%  #join using the country ID
      dplyr::select(paste0('y', yList))

    # convert the urban demand ratio to urban area
    urbanDemandBase <- urbanDemandRatio[1]
    urbanDemand <- list()
    for (i in 1:9) {
      if(i==1) {
        urbanDemand[i] = (urbanDemandRatio[i+1]-1)*urbanDemandBase
      } else {
        urbanDemand[i] <- (urbanDemandRatio[i+1] - urbanDemandRatio[i])*urbanDemandBase
      }
    }
    urbanDemand <- t(do.call(rbind, urbanDemand))*(0.905^2)

    # Start modeling
    tempZone <- as.logical(zoneLayer)
    tempUrban1 <- urbanLayer*tempZone
    tempDemand <- urbanDemand[]

    # Prepare suitlayer, PaLayer, and waterLayer
    tempsuitLayer <- suitLayer*tempZone
    temppaLayer <- PaLayer*tempZone
    tempwatLayer <- WatLayer*tempZone

    # Modeling for each year
    iterList = length(yList);
    tempUrbanNow = tempUrban1;
    iterNum = config$general$year_interval

    for(i in 1:iterList){

      log_info("Processing country {cntryId} for year {yList[i]}")

      count = 0
      demandGap = as.numeric(tempDemand[i]) #/iterNum

      while (demandGap > 0) {

        # Prepare neighborhood
        neiLayer = urban_neighbor(tempUrbanNow, 5)

        # Calcualte the development probability
        DevLayer = tempsuitLayer * neiLayer * temppaLayer * tempwatLayer

        # Pixels ranking ahead for conversion
        tempInd <- which((is.na(tempUrbanNow[])) & (!is.na(DevLayer[])) & (DevLayer[] > 0))

        # sort the values of DevLayer by descend
        tempVal <- DevLayer[tempInd]
        tempVal <- data.frame(cbind(tempVal, tempInd))
        tempVal <- arrange(tempVal, desc(tempVal))

        # Measure the gap of the demand
        if(length(tempInd) > demandGap){
          # select the new urban area
          tempSelInd <- tempVal[1:demandGap, 'tempInd']
          demandGap <- 0
        } else {
          tempSelInd <- tempInd
          demandGap <- demandGap - length(tempSelInd)
        }
        # assign the new urban area
        tempUrbanNow[tempSelInd] <-  1

        # control the repeated iteration time
        count = count + 1
        if (count > 5){
          break
        }}
      # stack the urban layers
      if(i == 1){
        tempUrbanMod = tempUrbanNow
      }else{
        tempUrbanMod = stack(tempUrbanMod, tempUrbanNow)
      }
    }
    # export the urban modelling results
    output_raster <- paste0(config$model$output_raster_dir, '/UrbanMod_', cntryId,'.tif')
    log_info("Writing output raster:  {output_raster}")

    writeRaster(tempUrbanMod, output_raster, overwrite=TRUE)
  }

  log_info("Completed model run in {Sys.time() - start_time} seconds.")

  # clean up logger
  write(readLines(log_file), config$general$log_file)
  unlink(log_file)
}
