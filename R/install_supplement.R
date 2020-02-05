

#' Install compressed remote data supplement locally
#'
#' Download and unpack example data supplement from Zenodo that matches the current installed
#' distribution.
#'
#' @param data_directory Full path to the directory you wish to install the example data to.
#' Must be write-enabled for the user.
#' @importFrom logger log_info
#' @export
install_supplement <- function(data_directory) {

  # list of version to archived zipped file data supplement
  # TODO: update link with final version data
  data_version_urls <- list('0.1.0' = 'https://zenodo.org/record/3629446/files/mwaskom/seaborn-v0.10.0.zip?download=1')

  # get the current version that is installed
  version <- packageVersion('citys2m')

  tryCatch({
    data_link <- data_version_urls[unlist(version)]
  }, error = function(condition) {
    log_info(paste0("Link to data missing for current version: ", version, ".  Please contact admin."))
  })

  temp_file <- tempfile()

  log_info(paste0("Downloading supplemental data for version ", version))
  download.file(data_link[[1]], temp_file)

  unzip(zipfile=temp_file, exdir = data_directory)

  log_info(paste0("Data extracted to ", data_directory))

  unlink(temp_file)
}
