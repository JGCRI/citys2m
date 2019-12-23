# This script used to model future urban expansion. 


# check the availability of required packages and install the uninstalled ones automatically
list.of.packages <- c("raster", 'rgeos', 'dplyr', 'tidyr','rgdal', 'snow', 'MASS', 'pROC', 'ggplot2', 'caret')
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
# Load packages into session 
lapply(list.of.packages, require, character.only = TRUE)

# source the functions from other script
source('3_code/Urban_neighbor.R')
source('3_code/SSPModeling.R')

fileTag <- read.csv('1_input/spatialVar.csv') 
mat.cntryid <- read.csv('1_input/SSPdata/SSP2_Urban.csv')
cntryid <- mat.cntryid[, 2]
uqCntry = unique(cntryid); # regard one country as an integer

for (cId in 1:length(uqCntry)){

  cntryId <- uqCntry[cId]  #regard one country as an integer
  
  # read the country boundary 
  zoneLayer <- raster(paste0('1_input/', fileTag[1,1], '/', fileTag[1,2], '_', cntryId, '.tif')) #regard one country as an integer
  zoneLayer[zoneLayer == 0] <- NA #remove the background area
  
  # add the land covers 
  coverLayer <- raster(paste0('1_input/', fileTag[2, 1], '/', fileTag[2, 2], '_', cntryId, '.tif'))
  
  # get the suitable layer 
  suitLayer <- raster(paste0('1_input/', fileTag[5, 1], '/', fileTag[5, 2], '_', cntryId, '.tif'))

  # get the urbanized areas
  urbanLayer <- raster(paste0('1_input/', fileTag[4, 1], '/', fileTag[4, 2], '_', cntryId, '.tif'))
  
  # Load exclusion map 
  # exclude the water area
  WatLayer <- coverLayer
  WatLayer[WatLayer == 0] <- NA  # assign NA for the water area 
  WatLayer = as.logical(WatLayer)*as.logical(zoneLayer)
  
  # exclude the projection area
  PaLayer = raster(paste0('1_input/', fileTag[3, 1], '/', fileTag[3, 2], '_', cntryId, '.tif'))
  PaLayer[PaLayer != 0] <- NA   # assign NA for the projection area 
  PaLayer = as.logical(1-PaLayer)*as.logical(zoneLayer)
  
  # Read the urban demand for each country
  urbanDemandRatio <- read.csv('1_input/SSPdata/SSP2_Urban.csv') %>%
    dplyr::filter(Code == uqCntry) %>%  #join using the country ID
    dplyr::select(paste0('y', seq(2010, 2100, 10)))
  # convert the urban demand ratio to urban area
  urbanDemandBase <- urbanDemandRatio[1]
  urbanDemand <- list()
  for (i in 1:9) {
    if(i==1) {
      urbanDemand[i] = (urbanDemandRatio[i+1]-1)*urbanDemandBase} else{ 
        urbanDemand[i] <- (urbanDemandRatio[i+1] - urbanDemandRatio[i])*urbanDemandBase} 
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
  
  yList = seq(2020, 2100, 10)  
  # Modeling for each year
  iterList = length(yList);
  tempUrbanNow = tempUrban1;
  iterNum = 10
  
  for(i in 1:iterList){
    
    count = 0
    demandGap = as.numeric(tempDemand[i]) #/iterNum
    
    while (demandGap > 0) {
      
      # Prepare neighborhood
      neiLayer = Urban_neighbor(tempUrbanNow, 5)
      
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
        # print(paste0demandGap)
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
  if(!dir.exists('2_output/ModelResults')) dir.create('2_output/ModelResults')
  writeRaster(tempUrbanMod, paste0('2_output/ModelResults/UrbanMod_', cntryId,'.tif'), overwrite=TRUE)  
  
  print(paste('Finish future urban modeling of Country Id', cntryId))
}
