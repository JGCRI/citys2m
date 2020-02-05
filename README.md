[![Build Status](https://travis-ci.org/JGCRI/citys2m.svg?branch=master)](https://travis-ci.org/JGCRI/citys2m)

# citys2m
A spatial urban sprawl model

## Description
The `citys2m` package is used to determine...

## Get Started with `citys2m`
`citys2m` can be installed directly from its GitHub repository using the R `devtools` package. From an R prompt, run the command:

```r
devtools::install_github('JGCRI/citys2m')
```

### Install the data supplement
An example data supplement containing all data required to run `citys2m` can be downloaded and unzipped to a user specified directory by running:

```r
library(citys2m)

citys2m::install_supplement("<the full path to the directory you want to extract the data to>")
```

This function requires that the user has write access to the selected directory.  NOTICE:  This data when extracted will take up to 3.7 GB of disk space.

### Setting up a run with `citys2m`
The `citys2m` model has two main functions that are used to conduct runs:
- `prepare_model()`:  this function prepares the urban sprawl data used by the main model function.
- `model()`:  this is the main model function that creates the urban sprawl spatial outputs.

These two functions take only one required argument:  a configuration YAML file.  This configuration file is broken out into the following three sections:

#### `general`
This section contains parameters that are used in both the `prepare_model()` and the `model()` functions.  They are as follows:
- `start_year`:  a four year integer for the start year of the simulation
- `through_year`:  a four year integer for the year to process through in the simulation
- `year_interval`:  an integer for the number of years in the time step

#### `prep_model`
This section contains parameters that are used in the `prepare_model()` function and are as follows:
- `ssp_gdp_file`: The future GDP data from SSP CSV file
- `hist_gdp_file`: The historical GDP data from world bank CSV file
- `population data`: Population data CSV file
- `global_model_file`:  The derived model for each country CSV file
- `country_id_file`:  The country ID CSV file
- `output_urban_file`: The output urban CSV file to be fed into the model run

#### `model`
This section contains parameters that are used in the `model()` function and are as follows:
- `spatial_var`: The spatial var CSV file
- `urban_csv`: The urban CSV file created by `prep_model()`
- `input_raster_dir`: The full path to the directory holding the input rasters
- `output_raster_dir`:  The full path to the directory where output rasters will be stored

A sample configuration file can be found here in this repository: `tests/testthat/config.yml`

### Example run
Once the configuration file has been set up, you can run `citys2m` using the following:

#### By running `prep_model()` first...
```r
library(citys2m)

config_file <- "<Full path to your configuration file with file name and extension>"

# run model preparation
citys2m::prep_model(config_file)

# run model
citys2m::model(config_file)
```
