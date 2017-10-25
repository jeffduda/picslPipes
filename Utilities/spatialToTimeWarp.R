library(ANTsR)

options(echo=FALSE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)

spatialWarp = antsImageRead(args[1])
#print(spatialWarp)
nTimes  = as.integer(args[2])
tr = as.numeric(args[3])
origin = as.numeric(args[4])
outWarpName = args[5]

outDim = c( dim(spatialWarp), nTimes )
outSpacing = c( antsGetSpacing(spatialWarp), tr )
outOrigin = c( antsGetOrigin(spatialWarp), origin )
outDir = matrix(0,4,4)
outDir[4,4] = 1
outDir[1:3,1:3] =  antsGetDirection(spatialWarp)

outWarpX = array(dim=outDim)#makeImage(outDim, spacing=outSpacing, direction=outDir, origin=outOrigin )
outWarpY =  array(dim=outDim)#makeImage(outDim, spacing=outSpacing, direction=outDir, origin=outOrigin )
outWarpZ =  array(dim=outDim)#makeImage(outDim, spacing=outSpacing, direction=outDir, origin=outOrigin )
outWarpT =  array(dim=outDim)#makeImage(outDim, spacing=outSpacing, direction=outDir, origin=outOrigin )

d = dim(outWarpX)

for (t in 1:nTimes ) {
  #print(dim(spatialWarp[1:d[1],1:d[2],1:d[3]]))
  outWarpX[1:d[1],1:d[2],1:d[3],t] = spatialWarp[1:d[1],1:d[2],1:d[3]][1,,,]
  outWarpY[1:d[1],1:d[2],1:d[3],t] = spatialWarp[1:d[1],1:d[2],1:d[3]][2,,,]
  outWarpZ[1:d[1],1:d[2],1:d[3],t] = spatialWarp[1:d[1],1:d[2],1:d[3]][3,,,]
}

outWarpX = as.antsImage(outWarpX, spacing=outSpacing, direction=outDir, origin=outOrigin)
outWarpY = as.antsImage(outWarpY, spacing=outSpacing, direction=outDir, origin=outOrigin)
outWarpZ = as.antsImage(outWarpZ, spacing=outSpacing, direction=outDir, origin=outOrigin)
outWarpT = as.antsImage(outWarpT, spacing=outSpacing, direction=outDir, origin=outOrigin)
warp = mergeChannels( list(outWarpX, outWarpY, outWarpZ, outWarpT) )
antsImageWrite( warp, outWarpName )
