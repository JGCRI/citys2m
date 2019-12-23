Urban_neighbor <- function(urbanMap, winSize){
# calculate the neighborhood using a window

# Args: 
# urbanMap: binary urban map (0-nonubran; 1-urban)
# winSize: window size
  
# Returns:
# a raster of neighborhood value indicating urban probability
 
# create a matrix 
  f <- matrix(1, nrow = winSize, ncol = winSize)
  f[(winSize*winSize+1)/2] <- 0
  
  urbanMap[is.na(urbanMap)] <- 0  
# apply the moving windows
  neiLayer <- focal(urbanMap, w=f, mean, na.rm=TRUE, pad=FALSE, padValue=NA)
 
  return(neiLayer)
}
