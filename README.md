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
- `prepare_model()`:  This function prepares the urban sprawl data used by the main model function.  This can be ran separately.
- `model()`:  This is the main model function that creates the urban sprawl spatial outputs.  The `model()` function uses the `prepare_model()` function if an existing urban file is not provided.

These two functions take only one required argument:  a configuration YAML file.  This configuration file is broken out into the following three sections:

#### `general`
This section contains parameters that are used in both the `prepare_model()` and the `model()` functions.  They are as follows:
- `start_year`:  A four year integer for the start year of the simulation
- `through_year`:  A four year integer for the year to process through in the simulation
- `year_interval`:  An integer for the number of years in the time step
- `log_file`:  The full path with file name and extension to the `logfile.log` to create

#### `prepare_model`
This section contains parameters that are used in the `prepare_model()` function and are as follows:
- `ssp_gdp_file`: The future GDP data from SSP CSV file with full path
- `hist_gdp_file`: The historical GDP data from world bank CSV file with full path
- `population data`: Population data CSV file with full path
- `global_model_file`:  The derived model for each country CSV file with full path
- `country_id_file`:  The country ID CSV file with full path
- `output_urban_file`: The output urban CSV file to be fed into the model run with full path.  If the user passes NULL for the `write_output` parameter, this file will not be created

#### `model`
This section contains parameters that are used in the `model()` function and are as follows:
- `spatial_var`: The spatial var CSV file with full path
- `urban_csv`: The urban CSV file created by `prepare_model()`.  Enter `NULL` if you wish to generate the urban data from the `prepare_model()` function instead of reading it from file.
- `input_raster_dir`: The full path to the directory holding the input rasters
- `output_raster_dir`:  The full path to the directory where output rasters will be stored

The following is a sample configuration YAML file (to be named with the `.yml` extension e.g. `config.yml`):
```yaml
general:

    # start year of simulation
    start_year: 2010

    # year to process through in simulation
    through_year: 2100

    # time step
    year_interval: 10

    # log file name and location
    log_file:  './outputs/logfile.log'

prepare_model:

    # future GDP data from SSP
    ssp_gdp_file: './inputs/SSPdata/SSP2_GDP.csv'

    # historical GDP data from world bank
    hist_gdp_file: './inputs/SSPdata/Hist_GDP.csv'

    # population data
    population_file: './inputs/SSPdata/SSP2_POP.csv'

    # derived model for each country file
    global_model_file:  './inputs/SSPdata/fitPara_global_sig.csv'

    # country ID file
    country_id_file:  './inputs/SSPdata/CntryID.csv'

    # output urban file to be fed into the model run; if `write_output` is set to NULL in code, this file will not be created
    output_urban_file: "./inputs/SSPdata/SSP2_Urban.csv"

model:

    # input files
    spatial_var: "./inputs/spatialVar.csv"

    # the urban CSV file generated from the `prepare_model` function.  NULL if generating in code.
    urban_csv: NULL

    # full path to the directory holding the input rasters
    input_raster_dir: "./inputs/"

    # full path to the directory where output rasters will be stored
    output_raster_dir: "./outputs"
```

A sample configuration file can be found here in this repository: `tests/testthat/config.yml`

### Example run
Once the configuration file has been set up, you can run `citys2m` using the following:

#### Run the model
```r
library(citys2m)

config_file <- "<Full path to your configuration file with file name and extension>"

# run model
citys2m::model(config_file)
```

#### Run only the `prepare_model()` function to create the urban input file
```r
library(citys2m)

config_file <- "<Full path to your configuration file with file name and extension>"

# run model preparation
citys2m::prepare_model(config_file)
```
