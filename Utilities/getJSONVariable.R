# getJSONVar.R
# get a variable from a .json file
# example: getJSONVariable.R info.json SliceTiming timing.csv

library(jsonlite)

options(echo=FALSE)
args <- commandArgs(trailingOnly = TRUE)

if ( length(args) != 3 ) {
  stop("Incorrect number of arguments");
}

dat = read_json(args[1])
vdat = unlist(get(args[2], dat))
odat = data.frame(vdat)
colnames(odat) = args[2]

write.csv(odat, args[3], row.names=F)
