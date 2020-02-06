# Test to make sure model outputs are consistent

context("Model results")

library(testthat)
library(raster)

test_that("Outputs from `model()`are ", {

  # load test comparison output
  test_expected <- raster("./comp_data/UrbanMod_84.tif")

  config_file <- "./config.yml"
  output_raster <- "./outputs/UrbanMod_84.tif"

  # run the model and generate results; test only a subset
  citys2m::model(config_file, list(84, 85))

  # read new output file
  new_raster <- raster(output_raster)

  # evaluates same extent, number of rows and columns, projection, resolution, and origin
  expect_true(compareRaster(test_expected, new_raster), info = paste("Output rasters are not the same."))

  # evaluates value equality
  expect_true(all.equal(test_expected, new_raster, check.attributes = FALSE), info = paste("Output rasters are not all.equal."))

})


test_that("Outputs from `prepare_model()`are ", {

  # load test comparison output
  test_expected <- read.csv("./comp_data/SSP2_Urban.csv", stringsAsFactors = FALSE)

  config_file <- "./config.yml"

  # run the `prepare_model` function and generate results
  output_df <- citys2m::prepare_model(config_yml = config_file, write_output = FALSE)

  print(all.equal(test_expected, output_df))

  # evaluates value equality
  expect_true(all.equal(test_expected, output_df), info = paste("Outputs for `prepare_model()` are not all.equal."))

})
