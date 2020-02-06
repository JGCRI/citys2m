# Test to make sure model outputs are consistent

context("Model results")

library(testthat)
library(raster)

test_that("Model outputs are ", {

  # load test comparison output
  test_expected <- raster("./comp_data/UrbanMod_84.tif")

  config_file <- "./config.yml"
  output_raster <- "./outputs/UrbanMod_84.tif"

  # run the model and generate results; test only a subset
  citys2m::model(config_file, list(84, 85))

  # read new output file
  new_raster <- raster(output_raster)

  expect_true(all.equal(test_expected, new_raster), info = paste("Output rasters are not the same."))

  expect_true(compareRaster(test_expected, new_raster), info = paste("Output rasters are not the same."))

})
