library(ANTsR)

options(echo=FALSE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)

boldImg = antsImageRead(args[1],4,pixeltype="double")
timing = read.csv(args[2])$SliceTiming

warpx = as.array(boldImg)*0
warpt = warpx

d = dim(boldImg)

for ( t in 1:length(timing) )
{
  offset = -timing[t]
  #print(paste(t,offset))
  warpt[1:d[1],1:d[2],t,1:d[4]] = offset
}

warpx = as.antsImage(warpx, spacing=antsGetSpacing(boldImg), direction=antsGetDirection(boldImg), origin=antsGetOrigin(boldImg))
warpt = as.antsImage(warpt, spacing=antsGetSpacing(boldImg), direction=antsGetDirection(boldImg), origin=antsGetOrigin(boldImg))

warp = mergeChannels( list(warpx, warpx, warpx, warpt) )
antsImageWrite( warp, args[3] )
