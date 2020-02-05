

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


#' Run the citys2m model
#'
#' @param config_yml Full path with file name to the configuration YAML file
#' @param target_country_ids Optional.  List of country ids to evaluate.
#' @importFrom yaml read_yaml
#' @importFrom raster raster writeRaster
#' @importFrom dplyr filter
#' @import raster
#' @import rgeos
#' @import dplyr
#' @import tidyr
#' @import rgdal
#' @import snow
#' @import MASS
#' @import pROC
#' @import ggplot2
#' @import caret
#' @export
model <- function(config_yml, target_country_ids=NA) {

  # read in configuration file
  config <- read_yaml(config_yml)

  fileTag <- read.csv(config$model$spatial_var)
  mat.cntryid <- read.csv(config$model$urban_csv)

  if (!is.na(target_country_ids)) {
    mat.cntryid <- filter(mat.cntryid, Code %in% target_country_ids)
  }

  cntryid <- mat.cntryid[, 2]
  uqCntry = unique(cntryid); # regard one country as an integer

  for (cId in 1:length(uqCntry)){

    cntryId <- uqCntry[cId]  #regard one country as an integer

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
    urbanDemandRatio <- read.csv(config$model$urban_csv) %>%
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
      print(paste0('finish the year of ', yList[i]))
    }
    # export the urban modelling results
    output_raster <- paste0(config$model$output_raster_dir, '/UrbanMod_', cntryId,'.tif')
    writeRaster(tempUrbanMod, output_raster, overwrite=TRUE)

    print(paste('Finish future urban modeling of Country Id', cntryId))
  }
}
