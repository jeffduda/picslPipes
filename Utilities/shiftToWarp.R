# shiftToWarp.R
# convert a voxel shift map (possibly from FSL) into an ANTs warp.
# example: shiftToWarp.R shiftmap.nii.gz 1 shiftwarp.nii.gz

library(ANTsRCore)

options(echo=FALSE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)

if ( length(args) != 3 ) {
  stop("Incorrect number of arguments");
}

valImg = antsImageRead(args[1],3,pixeltype="double")
dim = args[2]
vals = as.vector(as.array(valImg))


# create component images
xd = valImg*0
yd = valImg*0
zd = valImg*0
d = dim(xd)

# transpose of this?
dir = antsGetDirection(valImg)
v1=NA
v2=NA

if (dim == 1) {
  v1 = antsTransformIndexToPhysicalPoint(valImg, c(1,1,1) )
  v2 = antsTransformIndexToPhysicalPoint(valImg, c(2,1,1) )
}
else if (dim == 2 ) {
  v1 = antsTransformIndexToPhysicalPoint(valImg, c(1,1,1) )
  v2 = antsTransformIndexToPhysicalPoint(valImg, c(1,2,1) )
}
else if (dim == 3 ) {
  v1 = antsTransformIndexToPhysicalPoint(valImg, c(1,1,1) )
  v2 = antsTransformIndexToPhysicalPoint(valImg, c(1,1,2) )
}

refVec = v1-v2
vecs = rbind(vals*refVec[1], vals*refVec[2], vals*refVec[3])

xd[1:d[1],1:d[2],1:d[3]] = vecs[1,]
yd[1:d[1],1:d[2],1:d[3]] = vecs[2,]
zd[1:d[1],1:d[2],1:d[3]] = vecs[3,]

warp = mergeChannels( list(xd, yd, zd) )
antsImageWrite( warp, args[3] )
