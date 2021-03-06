library(ensemble)
library(randomForest)
library(mgcv)
library(nnet)
library(devtools)
if(Sys.info()[4]=="jb"){
  setwd("/media/storage/Professional Files/Mines/SmartGeo/Queens/")
  source("/media/storage/Github/SmartGeo/functions.R")
}
if(Sys.info()[4]=="JOSH_LAPTOP"){
  setwd("~/Professional Files/Mines/SmartGeo/Queens/")
  source("~/Github/SmartGeo/functions.R")
}
if(grepl("ch120", Sys.info()[4])){
  setwd("~/SmartGeo/Queens")
  source("~/Github/SmartGeo/functions.R")
}
load("Data/Cleaned_Data.RData")
rm(tunnel); gc()

#######################################################################
# Basic statistics: how many observations per station?
#######################################################################

length(unique(ground$Time))
length(unique(tunnel$Time)); dim(tunnel)
nrow(ground)/nrow(tunnel)
statNA = ddply(ground, "StationID", function(df){
  data.frame( cnt=sum(!is.na(df$Value))
             ,maxTime=max(df$Time[!is.na(df$Value)])
             ,minTime=min(df$Time[!is.na(df$Value)])
  )
} )
statNA = merge(station, statNA)
summary(statNA)
summary(station)#What?  How can we not have Northing/Easting for some stations!?
statNA$minTimePct = as.numeric(difftime(statNA$minTime,min(tunnel$Time),units="secs")) /
    as.numeric(difftime(max(tunnel$Time),min(tunnel$Time),units="secs"))
statNA$maxTimePct = as.numeric(difftime(max(tunnel$Time),statNA$maxTime,units="secs")) /
    as.numeric(difftime(max(tunnel$Time),min(tunnel$Time),units="secs"))
p = get_map( location=c(mean(statNA$Longitude, na.rm=T)+.0005, mean(statNA$Latitude, na.rm=T)), zoom=17 )
p = ggmap(p)
p1 = p + geom_point(data=statNA, aes(x=Longitude, y=Latitude, color=cnt) ) +
  labs(x="Longitude", y="Latitude", color="Observation Count")
p2 = p + geom_point(data=statNA, aes(x=Longitude, y=Latitude, color=minTimePct) ) +
  labs(x="Longitude", y="Latitude", color="First observation")
p3 = p + geom_point(data=statNA, aes(x=Longitude, y=Latitude, color=maxTimePct) ) +
  labs(x="Longitude", y="Latitude", color="Last observation")
grid.arrange(p1, p2, p3, ncol=3)
mean(statNA$cnt); max(statNA$cnt)
#Ok, so the average station only has 2000 obs. out of the total possible 11000.  The max
#is only 5759.  It also seems that observations on the west were measured more in the
#beginning, and observations on the east were measured more at the end.  The middle tends 
#to have the highest total counts.

ggsave("Results/Missing_Data.png",
  ggplot(ground, aes(x=Time, y=factor(StationID), fill=is.na(Value) ) ) +
      geom_tile() + labs(x="", y="Station", fill="Missing?") + scale_y_discrete(breaks=c())
  ,width=6, height=6 )


#######################################################################
# Basic statistics: Is deformation approximately normal?  Should we
# difference the time series?  Does drift seem to exist in stations
# that is proportional to x or y value?
#######################################################################

load("Data/ground_with_distance.RData")
load("Data/station_new_coords.RData")
station = station[!is.na(station$East2),]
ground = merge(ground, station, by="StationID")
ground = ground[!is.na(ground$Value),]
qplot( ground$Value[sample(1:nrow(ground), size=1000)] ) 

quan.time = quantile( as.numeric(ground$Time), 0:4/4 )
ground$TimeGroup = findInterval( as.numeric(ground$Time), quan.time )
quan.east = quantile( ground$East2, 0:4/4 )
ground$EastGroup = findInterval( as.numeric(ground$East2), quan.east )
quan.north = quantile( as.numeric(ground$North2), 0:4/4 )
ground$NorthGroup = findInterval( as.numeric(ground$North2), quan.north )
ground$TimeGroup[ground$TimeGroup>4] = 4
ground$EastGroup[ground$EastGroup>4] = 4
ground$NorthGroup[ground$NorthGroup>4] = 4
ground$TimeGroup = paste0("Time: Q", ground$TimeGroup)
ground$EastGroup = paste0("East: Q", ground$EastGroup)
ground$NorthGroup = paste0("North: Q", ground$NorthGroup)

ggsave("Results/displacement_distribution_by_easting.png",
  ggplot(ground, aes(x=Value, fill=factor(EastGroup), group=EastGroup ) ) +
    geom_bar(aes(y=..density..), binwidth=0.01) + facet_grid( EastGroup ~ . ) +
    xlim(c(-1,1)) + labs(x="Deformation", y="Density") +
    guides(fill=FALSE)
)
ggsave("Results/displacement_distribution_by_northing.png",
  ggplot(ground, aes(x=Value, fill=factor(NorthGroup), group=NorthGroup ) ) +
    geom_bar(aes(y=..density..), binwidth=0.01) + facet_grid( NorthGroup ~ . ) +
    xlim(c(-1,1)) + labs(x="Deformation", y="Density") +
    guides(fill=FALSE)
)
ggsave("Results/deformation_vs_east_by_north_time.png",
  ggplot( ground, aes(x=East2, y=Value) ) + geom_smooth() +
    facet_grid( NorthGroup ~ TimeGroup )
)
ggsave("Results/deformation_vs_north_by_east_time.png",
  ggplot( ground, aes(x=North2, y=Value) ) + geom_smooth() +
    facet_grid( EastGroup ~ TimeGroup )
)
ggsave("Results/deformation_vs_time_by_east_north.png",
  ggplot( ground, aes(x=Time, y=Value) ) + geom_smooth() +
    facet_grid( NorthGroup ~ EastGroup) + scale_x_datetime(breaks=c()) +
    labs(y="Deformation")
)

qplot( station$East2, station$North2 )
eastGrid = seq(min(station$East2), max(station$East2), 20)
grp = eastGrid[findInterval( station$East2, eastGrid)]
qplot( station$East2, station$North2, color=factor(grp) ) + guides(color=F) +
  geom_vline(data=data.frame(grp=grp), aes(xintercept=grp), alpha=.5 )
ground$MeanEast = eastGrid[findInterval(ground$East2, eastGrid)]

qplot( station$East2, station$North2 )
northGrid = seq(min(station$North2), max(station$North2), 4)
grp = northGrid[findInterval( station$North2, northGrid)]
qplot( station$East2, station$North2, color=factor(grp) ) + guides(color=F) +
  geom_hline(data=data.frame(grp=grp), aes(yintercept=grp), alpha=.5 )
ground$MeanNorth = northGrid[findInterval(ground$North2, northGrid)]

ggsave("Results/deformation_vs_time_by_east_north_actual_free_scale.png",
  ggplot( ground, aes(x=Time, y=Value) ) + geom_smooth() +
    facet_grid( MeanNorth ~ MeanEast, scale="free")
  ,width=30, height=30)

ggsave("Results/deformation_vs_time_by_east_north_actual.png",
  ggplot( ground, aes(x=Time, y=Value) ) + geom_smooth() +
    facet_grid( MeanNorth ~ MeanEast)
  ,width=30, height=30)


#######################################################################
# Model Deformation as a non-linear function of Time, North2, East2,
# and distances from tunnels.  Try some different models, evaluate
# based on cross-validation.
#######################################################################

load("Data/ground_with_distance.RData")
load("Data/station_new_coords.RData")
station = station[!is.na(station$East2),]
ground = ground[!is.na(ground$Value),]
ground = ground[!is.na(ground$East2),]
ground$deltaValue=NULL
ground$nnetTime = as.numeric(ground$Time)

# #eastGrid = seq(min(station$East2), max(station$East2), 20)
# eastGrid = seq(min(station$East2), max(station$East2), 100)
# grp = eastGrid[findInterval( station$East2, eastGrid)]
# ground$MeanEast = eastGrid[findInterval(ground$East2, eastGrid)]
# #northGrid = seq(min(station$North2), max(station$North2), 4)
# northGrid = seq(min(station$North2), max(station$North2), 20)
# grp = northGrid[findInterval( station$North2, northGrid)]
# ground$MeanNorth = northGrid[findInterval(ground$North2, northGrid)]

#Define cross-validation groups
stationGrp = data.frame(StationID=station$StationID, grp=sample( c(1,rep(1:10, each=37)) ) )
ground = merge(ground, stationGrp, by="StationID")
stationGrp = data.frame(StationID=station$StationID, grp2=sample( c(rep(-1,271),rep(1:10, each=10)) ) )
ground = merge(ground, stationGrp, by="StationID")

modGLM = cvModel(glm, cvGroup=ground$grp, d=ground
       ,form=Value ~ A + BC + D + YL + East2 + North2 + nnetTime, saveMods=TRUE )
save(modGLM, file="modGLM")
ensem = modGLM$ensemble
save(ensem, file="modGLMensemble")
modGLM2 = cvModel(glm, cvGroup=ground$grp, d=ground
       ,form=Value ~ (A + BC + D + YL + nnetTime) * East2 * North2, saveMods=TRUE )
save(modGLM2, file="modGLM2")
ensem = modGLM2$ensemble
save(ensem, file="modGLM2ensemble")
modGLM3 = cvModel(glm, cvGroup=ground$grp, d=ground
       ,form=Value ~ (A + BC + D + YL + nnetTime) * factor(MeanEast) * factor(MeanNorth), saveMods=TRUE )
save(modGLM3, file="modGLM3")
ensem = modGLM3$ensemble
save(ensem, file="modGLM3ensemble")
modRF = cvModel(randomForest, cvGroup=ground$grp2, d=ground
       ,form=Value ~ A + BC + D + YL + East2 + North2 + nnetTime, saveMods=TRUE )
save(modRF, file="modRF")
ensem = modRF$ensemble
save(ensem, file="modRFensemble")
modGAM = cvModel(gam, cvGroup=ground$grp2, d=ground
       ,form=Value ~ s(A) + s(BC) + s(D) + s(YL) + s(East2) + s(North2) + s(nnetTime), saveMods=TRUE )
save(modGAM, file="modGAM")
ensem = modGAM$ensemble
save(ensem, file="modGAMensemble")

#nnet fails with large parameters, so scale them down by constants
ground$nnetTime = (ground$nnetTime-mean(ground$nnetTime))/sd(ground$nnetTime)
ground$nnetA = (ground$A-mean(ground$A))/sd(ground$A)
ground$nnetBC = (ground$BC-mean(ground$BC))/sd(ground$BC)
ground$nnetD = (ground$D-mean(ground$D))/sd(ground$D)
ground$nnetYL = (ground$YL-mean(ground$YL))/sd(ground$YL)
ground$nnetEast2 = (ground$East2-mean(ground$East2))/sd(ground$East2)
ground$nnetNorth2 = (ground$North2-mean(ground$North2))/sd(ground$North2)
modNNET = cvModel(nnet, cvGroup=ground$grp, d=ground
       ,form=Value ~ A + BC + D + YL + East2 + North2 + Time, saveMods=TRUE,
       args=list(size=10, linout=TRUE, maxit=100000))
save(modNNET, file="modNNET")
ensem = modNNET$ensemble
save(ensem, file="modNNETensemble")

load("Results/modNNETensem")
ensemble = ensem; colnames(ensemble)[1] = "NNET"
load("Results/modRFensem")
ensemble = cbind(ensemble, ensem); colnames(ensemble)[2] = "RF"
load("Results/modGLMensem")
ensemble = cbind(ensemble, ensem); colnames(ensemble)[3] = "GLM"
load("Results/modGLM2ensem")
ensemble = cbind(ensemble, ensem); colnames(ensemble)[4] = "GLM2"
load("Results/modGAMensem")
ensemble = cbind(ensemble, ensem); colnames(ensemble)[5] = "GAM"

sqrt( mean( (ground$Value-ensemble[,1])[!ground$outlier]^2 ) )
sqrt( mean( (ground$Value-ensemble[,2])[!ground$outlier]^2 ) )
sqrt( mean( (ground$Value-ensemble[,3])[!ground$outlier]^2 ) )
sqrt( mean( (ground$Value-ensemble[,4])[!ground$outlier]^2 ) )
sqrt( mean( (ground$Value-ensemble[,5])[!ground$outlier]^2 ) )

#Remove some unneeded columns of ground to free up some RAM
ground$deltaValue = NULL
ground$Easting = NULL
ground$Northing = NULL
ground$Longitude = NULL
ground$Latitude = NULL
gc()
load("Results/modNNET")
#Make sure ground variables have been reduced by factors
for(i in 1:10){
  ground$Prediction = predict( modNNET$models[[i]], newdata=ground, type="raw" )
  ggsave(paste0("Results/NNET_deformation_vs_time_by_east_north_actual_free_scale_",i,".png"),
      ggplot( ground, aes(x=Time, y=Prediction) ) + geom_smooth() +
        facet_grid( MeanNorth ~ MeanEast, scale="free")
    ,width=30, height=30)
  ggsave(paste0("Results/NNET_deformation_vs_time_by_east_north_actual_",i,".png"),
      ggplot( ground, aes(x=Time, y=Prediction) ) + geom_smooth() +
        facet_grid( MeanNorth ~ MeanEast)
    ,width=30, height=30)
}
save(ground, file="Data/ground_for_nnet.RData")
fit = nnet( form=Value ~ nnetA + nnetBC + nnetD + nnetYL + nnetEast2 + nnetNorth2 + nnetTime,
    data=ground, size=10, linout=TRUE, maxit=100000)
save(fit, file="Results/nnet_model_all_data.RData")
ground$Prediction = predict(fit, newdata=ground)
save(ground, file="Data/ground_with_nnet.RData")

load("Results/nnet_model_all_data.RData")
source_url("https://gist.githubusercontent.com/fawda123/7471137/raw/e297a212033087021bdd770625a0f09024a22882/nnet_plot_update.r")
wts = plot.nnet(fit, wts.only=TRUE)
wtsHid = do.call("rbind", wts[1:10])
colnames(wtsHid) = c("Intercept", "A", "BC", "D", "YL", "East", "North", "Time")
rownames(wtsHid) = paste("Hidden Node",1:10)
xtable(wtsHid)
wtsOut = data.frame(Output=wts[[11]])
rownames(wtsOut) = c("Intercept", paste("Node",1:10))
xtable(wtsOut)

ground$Error = ground$Value - ground$Prediction
ggsave(paste0("Results/NNET_errors_vs_time_by_east_north.png"),
    ggplot( ground, aes(x=Time, y=Error) ) + geom_smooth() +
      facet_grid( MeanNorth ~ MeanEast)
  ,width=30, height=30)

#######################################################################
#Plot each station individually, look for errors of both types
#######################################################################

load("Data/ground_with_distance.RData")
for(stat in unique(ground$StationID) ){
  temp = ground[ground$StationID==stat & !ground$outlier,]
  temp$closeTunnel = ifelse( temp$A<300, "A"
                          ,ifelse(temp$BC<300, "BC"
                          ,ifelse(temp$D<300, "D"
                          ,ifelse(temp$YL<300, "YL", "None" ) ) ) )
  temp$closeTunnel = factor(temp$closeTunnel, levels=c("YL", "A", "BC", "D", "None") )
  temp$closeTunnel[temp$closeTunnel=="None"] = NA
  temp$deltaValue = c(diff(temp$Value), NA)
  p = ggplot(temp, aes(x=Time) ) + 
    geom_line(aes(y=Value), alpha=.8) +
    coord_cartesian(y=c(min(temp$Value, na.rm=T)-.1, max(temp$Value, na.rm=T)+.1) ) +
    labs(x="", y="Deformation", fill="Tunnel", title=paste("Station",stat)) +
    guides(alpha=F)
  if(sum(!is.na(temp$closeTunnel))>0)
    p = p + geom_tile(data=temp[!is.na(temp$closeTunnel),],
      aes(y=0,fill=closeTunnel, alpha=.1, height=1000))

  xRng = as.POSIXct( range(temp$Time[!is.na(temp$Value)]) )
  ggsave(paste0("Results/Univariate_Time_Series/Station_",stat,".png"),
    p + coord_cartesian(y=c(-0.5,0.5), x=xRng)
  )
  
#  ggsave(paste0("Results/Univariate_Time_Series/Station_1137.png"),
#    p + coord_cartesian(x=xRng, y=c(-.8,.3))
#  )
  
  p = ggplot(temp, aes(x=Time) ) + 
    geom_line(aes(y=deltaValue), alpha=.8) +
    coord_cartesian(y=c(min(temp$deltaValue, na.rm=T)-.1, max(temp$deltaValue, na.rm=T)+.1) ) +
    labs(x="", y="Deformation", fill="Tunnel", title=paste("Station",stat,"Deltas")) +
    guides(alpha=F)
  if(sum(!is.na(temp$closeTunnel))>0)
    p = p + geom_tile(data=temp[!is.na(temp$closeTunnel),],
      aes(y=0,fill=closeTunnel, alpha=.1, height=1000))
  ggsave(paste0("Results/Univariate_Time_Series/Station_",stat,"_delta.png"),
    p + coord_cartesian(y=c(-0.5,0.5))
  )
}

#######################################################################
#Study temporal dependence: plot deformation at time t vs. at time t-1
#######################################################################

if(!"Temporal Correlation" %in% list.files("Results"))
  dir.create("Results/Temporal Correlation")

load("Data/Cleaned_Data.RData")
out = dlply(ground, "StationID", function(df){
  vals = df$Value
  ggsave(paste0("Results/Temporal Correlation/Deformation_", df$StationID[1], ".png"),
    qplot(vals[-length(vals)], vals[-1]) + labs(x="Deformation(t)", y="Deformation(t+1)") +
      xlim(c(-1,1)) + ylim(c(-1,1)) + geom_smooth()
  )
} )

load("Data/ground_with_nnet.RData")
out = dlply(ground, "StationID", function(df){
  vals = df$Prediction - df$Value
  ggsave(paste0("Results/Temporal Correlation/nnet_Error_", df$StationID[1], ".png"),
    qplot(vals[-length(vals)], vals[-1]) + labs(x="Error(t)", y="Error(t+1)") +
      xlim(c(-1,1)) + ylim(c(-1,1)) + geom_smooth()
  )
} )

#######################################################################
#Apply the robust SNHT to each station individually, completely ignoring spatial relationships.
#######################################################################

temp = ground[ground$StationID==202,]
snhtVals = dlply(ground[!ground$outlier,], "StationID", function(df){
  out = snht(df$Value, period=10*60, robust=T)
  return(out$score)
})
save(snhtVals, file="Results/snhtVals.RData")
#load("Results/snhtVals.RData")
snhtMat = do.call("cbind", snhtVals)
summary( as.numeric(snhtMat) )
largeBreaks = apply(snhtMat, 2, max, na.rm=T)>1000
for(i in (1:ncol(snhtMat))[largeBreaks]){
  #Grab data from ground for this StationID only:
  g = filter( ground, StationID==as.numeric(colnames(snhtMat)[i]) )
  naFilt = !is.na(snhtMat[,i])
  print( qplot( g$Time[naFilt], g$Value[naFilt], color=snhtMat[naFilt,i]) +
    labs(title=paste("Station", colnames(snhtMat)[i])) )
  readline("Next?")
}

thresh = 100
tunnel = group_by(ground, Time)
tunnelDist = summarize(tunnel
  ,A=mean(A, na.rm=T)
  ,BC=mean(BC, na.rm=T)
  ,D=mean(D, na.rm=T)
  ,YL=mean(YL, na.rm=T) )
tunnelDist$closeTunnel = ifelse(tunnelDist$A<500, "A"
                        ,ifelse(tunnelDist$BC<500, "BC"
                        ,ifelse(tunnelDist$D<500, "D"
                        ,ifelse(tunnelDist$YL<500, "YL", NA ) ) ) )
#What % exceed the threshold as a function of time?
qplot(tunnelDist$Time
     ,apply(snhtMat, 1, function(x){ sum(x>thresh, na.rm=T)/sum(!is.na(x)) })
     ,geom="line") +
  geom_tile(data=tunnelDist
      ,aes(x=Time, y=0.5, fill=closeTunnel, alpha=is.na(closeTunnel)), height=1) +
  scale_alpha_manual(breaks=c(T,F), values=c(.5,0)) + guides(alpha=F) +
  coord_cartesian(ylim=c(0,.1)) +
  scale_y_continuous("Stations exceeding threshold", label=percent) 

#TO-DO!  Look for spatio-temporal relationships in snht values
#TO-DO!  Examine observed change points, create function to simulate similar errors.

#######################################################################
# Investigate times when tunnels are close to data
#######################################################################

load("Data/Cleaned_Data.RData")
YL = grepl("\\.YL", colnames(tunnel))
A = grepl("\\.A", colnames(tunnel))
D = grepl("\\.D", colnames(tunnel))
BC = grepl("\\.BC", colnames(tunnel))
minYLdist = apply( tunnel[,YL], 1, min, na.rm=T)
minAdist = apply( tunnel[,A], 1, min, na.rm=T)
minDdist = apply( tunnel[,D], 1, min, na.rm=T)
minBCdist = apply( tunnel[,BC], 1, min, na.rm=T)
bnd1 = geom_vline(xintercept=800)
bnd2 = geom_vline(xintercept=4500)
qplot( 1:length( minYLdist ), minYLdist, geom="line" ) + bnd1 + bnd2
qplot( 1:length( minAdist ), minAdist, geom="line" ) + bnd1 + bnd2
qplot( 1:length( minDdist ), minDdist, geom="line" ) + bnd1 + bnd2
qplot( 1:length( minBCdist ), minBCdist, geom="line" ) + bnd1 + bnd2
prd1 = 1:800
prd2 = 801:4500
prd3 = 4501:nrow(tunnel)

#######################################################################
# Investigate slope of region, determine transformation
#######################################################################

slope=.249
ggplot( station, aes(x=Easting, y=Northing) ) + geom_point() +
  geom_abline(intercept=30+211714.3-slope*1003357, slope=slope)
theta = atan(slope)
theta*180/pi #About 14 degrees off of East
#Rotate coordinate system by theta degrees counterclockwise:
station$East2 = station$Easting*cos(theta) + station$Northing*sin(theta)
station$North2 = -station$Easting*sin(theta) + station$Northing*cos(theta)
ggplot( station, aes(x=East2, y=North2) ) + geom_point()
save(station, file="Data/station_new_coords.RData")

#######################################################################
# Play with RFsim from CompRandFld package
#######################################################################

n = 20
nT = 20
x = 1:n
y = 1:n
t = 1:nT

d = RFsim(x, y, t, corrmodel="exp_exp", grid=TRUE
  ,param=list(nugget=0, mean=0,scale_s=2, scale_t=2,sill=1)
)$data
for(i in 1:dim(d)[3]){
  image.plot(1:n, 1:n, d[,,i], zlim=c(min(d),max(d)))
  Sys.sleep(1)
}
mod = FitComposite(data=d[,,1], coordx=1:n, coordy=1:n, corrmodel="exponential", grid=TRUE)
mod = FitComposite(data=d[,,2], coordx=1:n, coordy=1:n, corrmodel="exponential", grid=TRUE)
mod = FitComposite(data=d[,,3], coordx=1:n, coordy=1:n, corrmodel="exponential", grid=TRUE)
mod = FitComposite(data=d[,,4], coordx=1:n, coordy=1:n, corrmodel="exponential", grid=TRUE)
mod = FitComposite(data=d, coordx=1:n, coordy=1:n, coordt=1:nT
  ,corrmodel="exp_exp", grid=TRUE)

#######################################################################
# Model deformation as a function of distance
#######################################################################

source_github("https://raw.githubusercontent.com/rockclimber112358/Random_Code/master/plot_gam.R")
load("Data/ground_with_distance.RData")
load("Data/station_new_coords.RData")
station = station[!is.na(station$East2),]
ground = merge(ground, station[,c("StationID", "East2", "North2")]
        ,by="StationID")
ground = ground[!is.na(ground$Value),] #remove cases without deformation data
fit = gam( deltaValue ~ s(A) + s(BC) + s(D) + s(YL) + s(Time), data=ground )
save(fit, file="Results/gam_model.RData")
summary(fit)
plot(fit)

#######################################################################
# Fit Spatio-temporal variograms with real data!
#######################################################################

#Slope of region is about 20 degrees
start = Sys.time()
temp = ground[ground$Time<=ground$Time[1000],]
temp = merge(temp, station, by="StationID")
temp = temp[!is.na(temp$Longitude),]
coordinates(temp) = c("Easting", "Northing")
dirs = 4
v = variogram(Value ~ 1, data=temp[!is.na(temp$Value),]
    ,alpha=20-180/(2*dirs)+1:dirs*180/dirs)
ggplot(v, aes(x=dist, y=gamma)) + geom_point() +
  facet_wrap( ~ dir.hor )
Sys.time()-start
save(v, file="Results/Variogram_t_1:1000.RData")

temp = ground[ground$Time<=ground$Time[10],]
temp = merge(temp, station, by="StationID")
temp = temp[!is.na(temp$Longitude),]
coordinates(temp) = c("Easting", "Northing")
v2 = variogram(Value ~ 1, data=temp[!is.na(temp$Value),]
    ,alpha=20-180/(2*dirs)+1:dirs*180/dirs, cloud=TRUE)
ggplot( data.frame(v2), aes(x=dist, y=gamma) ) +
  geom_point(alpha=.002) + facet_wrap( ~ dir.hor) + geom_smooth() +
  coord_cartesian(ylim=c(0,.05))

v2 = variogram(Value ~ 1, data=temp[!is.na(temp$Value),], cloud=TRUE, cressie=TRUE)
ggplot( data.frame(v2), aes(x=dist, y=gamma) ) +
  geom_point(alpha=.002) + facet_wrap( ~ dir.hor) + geom_smooth()

temp = ground[ground$Time<=ground$Time[1000],]
temp = merge(temp, station, by="StationID")
temp = temp[!is.na(temp$Longitude),]
coordinates(temp) = c("Easting", "Northing")
v3 = variogram(Value ~ 1, data=temp[!is.na(temp$Value),], cressie=TRUE)
ggplot( data.frame(v3), aes(x=dist, y=gamma) ) +
  geom_point(alpha=1)

timeVg = dlply( ground[ground$Time<=ground$Time[100],], "Time", function(df){
    df = merge(df, station, by="StationID")
    df = df[!apply(df,1,function(x) any(is.na(x))),]
    coordinates(df) = c("Easting", "Northing")
    out = data.frame(variogram(Value ~ 1, data=df, cloud=T))
    out$Time = df$Time[1]
    return(out)
  } )
#timeVg2 = dlply( ground[ground$Time<=ground$Time[1],], "Time", function(df){
#    df = merge(df, station, by="StationID")
#    df = df[!apply(df,1,function(x) any(is.na(x))),]
#    out = data.frame( dist=as.numeric( dist( df[,c("Easting", "Northing")] ) )
#                     ,gamma=as.numeric( dist(df$Value)^2 ) )/2
#    return( out )
#  } )
timeVg = do.call("rbind", timeVg)

#Variogram appears to be flat, and so it may be ok to assume spatial independence
ggplot(timeVg[sample(1:nrow(timeVg),size=5000),], aes(x=dist, y=gamma) ) +
  geom_point() + geom_smooth() + coord_cartesian( ylim=c(0,.1) )



#################################################################
# Isotropy check
#################################################################

times = unique(ground$Time)
timeVg = NULL
for(i in 6136:length(times)){
  df = ground[ground$Time==times[i],]
  df = merge(df, station, by="StationID")
  df = df[!apply(df,1,function(x) any(is.na(x))),]
  if(nrow(df)==0)
    next;
  coordinates(df) = c("Easting", "Northing")
  out = try(data.frame(variogram(Value ~ 1, data=df, cloud=T, alpha=0:35*10)))
  if(nrow(out)==0)
    next;
  if(is(out,"try-error"))
    next;
  out$Time = df$Time[1]
  timeVg = rbind(timeVg, out)
  cat("Iteration",i,"completed out of",length(times),"\n")
  if(i %% 100 == 0){
    save(timeVg, file=paste0("Results/time_variogram_times_",i-99,"_",i) )
    timeVg = NULL
  }
}
save(timeVg, file=paste0("Results/time_variogram_times_",i) )

files = list.files("Results/")
files = files[grepl("time_variogram",files)]
meanVg = NULL
for(file in files){
  load(paste0("Results/",file))
  timeVg$dist2 = floor(timeVg$dist/10)*10
  meanVgTemp = ddply( timeVg, c("dir.hor", "dist2"), function(df){
    data.frame( gamma=mean(df$gamma), np=nrow(df) )
  } )
  meanVgTemp$file = file
  meanVg = rbind(meanVg, meanVgTemp)
}
meanVg$i = as.numeric( gsub("(time_variogram_times_|_[0-9]*)", "", meanVg$file) )
ggplot( meanVg, aes(x=dist2, y=gamma, color=i, group=i) ) + geom_line() +
  facet_wrap( ~ dir.hor, scale="free" )

#Aggregate over all time points, estimate the overall variogram and sd.
vgTotal = ddply(meanVg, c("dir.hor", "dist2"), function(df){
  out = data.frame(gamma=sum(df$gamma*df$np)/sum(df$np)
            ,np=sum(df$np) )
  out$sd = sqrt(2*out$gamma^2/out$np)
  return(out)
} )
ggsave("Results/anisotropic_investigation.png",
  ggplot( vgTotal[vgTotal$dir.hor<180,], aes(x=dist2) ) + geom_line(aes(y=gamma)) +
    geom_ribbon( aes(ymin=gamma-sd, ymax=gamma+sd), alpha=.2 ) +
    facet_wrap( ~ dir.hor ) + coord_cartesian(ylim=c(0,.2))
)

#Aggregate over all time points, estimate the overall variogram and sd.
vgTotal = ddply(meanVg[meanVg$i<2000,], c("dir.hor", "dist2"), function(df){
  out = data.frame(gamma=sum(df$gamma*df$np)/sum(df$np)
            ,np=sum(df$np) )
  out$sd = sqrt(2*out$gamma^2/out$np)
  return(out)
} )
ggsave("Results/anisotropic_investigation_pretunnel.png",
  ggplot( vgTotal[vgTotal$dir.hor<180,], aes(x=dist2) ) + geom_line(aes(y=gamma)) +
    geom_ribbon( aes(ymin=gamma-sd, ymax=gamma+sd), alpha=.2 ) +
    facet_wrap( ~ dir.hor )# + coord_cartesian(ylim=c(0,.2))
)

meanVg$dir.hor2 = floor(meanVg$dir.hor/45)*45
meanVg$dir.hor2[meanVg$dir.hor2>=180] = meanVg$dir.hor2[meanVg$dir.hor2>=180]-180
meanVgSub = ddply(meanVg, c("dir.hor2", "dist2", "i"), function(df){
  data.frame( gamma=mean(df$gamma, na.rm=T) )
} )
ggplot( meanVgSub, aes(x=dist2, y=gamma, color=i, group=i) ) + geom_line(alpha=.2) +
  facet_wrap( ~ dir.hor2, scale="free" ) + geom_smooth(aes(group=NA)) +
  labs(x="Distance", y="Variogram", color="Time Step")

#################################################################
# Space-time modeling: Raw deformation, all stations
#################################################################

rm(ground)
ground = loadGround(timeCnt=12000)
load("Data/station_new_coords.RData")

fits = list()
for( prd in list(prd1, prd2, prd3) ){
#for( prd in list(prd2, prd3) ){
  fit = empVario(data=ground[ground$Time %in% unique(tunnel$Time)[prd],]
    ,tlags=0:30*9, alpha=c(0,45,90,135), varName="Value", boundaries=0:65*10, cutoff=650)
  fits[[length(fits)+1]] = fit
  print(plot.empVario(fit, boundaries=0:65*10, model=F))
  save(fits, prd1, prd2, prd3, file="Results/new_sp_variograms.RData")
}
save(fits, prd1, prd2, prd3, file="Results/new_sp_variograms.RData")
#load("Results/new_sp_variograms.RData")

png("Results/new_sp_variograms_pretunnel.png", width=8, height=12, units="in", res=400)
  plot.empVario(fits[[1]], boundaries=0:15*36.46384, model=F)
dev.off()

toPlot = fits[[1]]
toPlot[[1]] = toPlot[[1]][toPlot[[1]]$dist<=500,]
png("Results/Final Variograms/raw_data_prd1.png", width=800, height=800)
plot.empVario(toPlot, boundaries=0:65*10, model=NULL, rmAni=T)
dev.off()
toPlot = fits[[2]]
toPlot[[1]] = toPlot[[1]][toPlot[[1]]$dist<=500,]
png("Results/Final Variograms/raw_data_prd2.png", width=800, height=800)
plot.empVario(toPlot, boundaries=0:65*10, model=NULL, rmAni=T)
dev.off()
toPlot = fits[[3]]
toPlot[[1]] = toPlot[[1]][toPlot[[1]]$dist<=500,]
png("Results/Final Variograms/raw_data_prd3.png", width=800, height=800)
plot.empVario(toPlot, boundaries=0:65*10, model=NULL, rmAni=T)
dev.off()

#################################################################
# Space-time modeling: Raw deformation, two station groups
#################################################################

rm(ground)
ground = loadGround(timeCnt=12000)
load("Data/station_new_coords.RData")

# station$Group = ifelse(station$North2> -36950, NA
#                ,ifelse(station$North2> -37010, "Test", "Control") )
# qplot( station$East2, station$North2, color=factor(station$Group))
# ground = merge(ground, station[,c("StationID", "Group", "East2", "North2")], by="StationID")
fits.test = list()
fits.ctl = list()
for( prd in list(prd1, prd2, prd3) ){
#for( prd in list(prd2, prd3) ){
  filt = ground$Time %in% unique(tunnel$Time)[prd] & !ground$outlier & !is.na(ground$Group)

  fit.test = empVario(data=ground[filt & ground$Group=="Test",]
    ,tlags=0:30*9, alpha=c(0,45,90,135), varName="Value", boundaries=0:65*10, cutoff=650)
  fits.test[[length(fits.test)+1]] = fit.test
  print(plot.empVario(fit.test, boundaries=0:65*10, model=F))
  save(fits.test, prd1, prd2, prd3, file="Results/new_sp_variograms_test_only.RData")

  fit.ctl = empVario(data=ground[filt & ground$Group=="Control",]
    ,tlags=0:30*9, alpha=c(0,45,90,135), varName="Value", boundaries=0:65*10, cutoff=650)
  fits.ctl[[length(fits.ctl)+1]] = fit.ctl
  print(plot.empVario(fit.ctl, boundaries=0:65*10, model=F))
  save(fits.ctl, prd1, prd2, prd3, file="Results/new_sp_variograms_control_only.RData")
}
save(fits.test, prd1, prd2, prd3, file="Results/new_sp_variograms_test_only.RData")
save(fits.ctl, prd1, prd2, prd3, file="Results/new_sp_variograms_control_only.RData")
#load("Results/new_sp_variograms.RData")


#################################################################
# Space-time modeling: Error from nnet, one model
#################################################################

rm(ground)
load("Data/ground_with_nnet.RData")
load("Data/station_new_coords.RData")
ground$Error = ground$Value - ground$Prediction
qplot( ground$Error )
qplot( ground$Error[!ground$outlier] )
qplot( ground$Error[!ground$outlier] ) + xlim(c(-1,1))
qplot(ground$Prediction, ground$Value, geom="smooth")
#ground$Time = ground$Time*1E9
#ground$Time = as.POSIXct(ground$Time, tz="EST", origin=as.POSIXct("1970-01-01", tz="UCT"))
fits = list()
for( prd in list(prd1, prd2, prd3) ){
#for( prd in list(prd2, prd3) ){
  fit = empVario(data=ground[ground$Time %in% unique(tunnel$Time)[prd] & !ground$outlier,]
    ,tlags=0:30*9, alpha=c(0,45,90,135), varName="Error", boundaries=0:65*10, cutoff=650)
  fits[[length(fits)+1]] = fit
  print(plot.empVario(fit, boundaries=0:65*10, model=F, adj=TRUE, boundaries=0:65*10))
  save(fits, prd1, prd2, prd3, file="Results/new_sp_variograms_error.RData")
}
save(fits, prd1, prd2, prd3, file="Results/new_sp_variograms_error.RData")


#################################################################
# Space-time modeling: Error from nnet, two models (shouldn't be needed)
#################################################################

rm(ground)
load("Data/ground_with_nnet.RData")
load("Data/station_new_coords.RData")

ground$Error = ground$Value - ground$Prediction
qplot( ground$Error )
qplot( ground$Error[!ground$outlier] )
qplot( ground$Error[!ground$outlier] ) + xlim(c(-1,1))

fits.test = list()
fits.ctl = list()
for( prd in list(prd1, prd2, prd3) ){
  filt = ground$Time %in% unique(tunnel$Time)[prd] & !ground$outlier & !is.na(ground$Group)

  fit.test = empVario(data=ground[filt & ground$Group=="Test",]
    ,tlags=0:30*9, alpha=c(0,45,90,135), varName="Error", boundaries=0:65*10, cutoff=650)
  fits.test[[length(fits.test)+1]] = fit.test
  print(plot.empVario(fit.test, boundaries=0:65*10, model=F))
  save(fits.test, prd1, prd2, prd3, file="Results/new_sp_variograms_error_test_only.RData")

  fit.ctl = empVario(data=ground[filt & ground$Group=="Control",]
    ,tlags=0:30*9, alpha=c(0,45,90,135), varName="Error", boundaries=0:65*10, cutoff=650)
  fits.ctl[[length(fits.ctl)+1]] = fit.ctl
  print(plot.empVario(fit.ctl, boundaries=0:65*10, model=F))
  save(fits.ctl, prd1, prd2, prd3, file="Results/new_sp_variograms_error_control_only.RData")
}
save(fits.test, prd1, prd2, prd3, file="Results/new_sp_variograms_error_test_only.RData")
save(fits.ctl, prd1, prd2, prd3, file="Results/new_sp_variograms_error_control_only.RData")

#################################################################
# Space-time modeling: Error from nnet, one model, short tlags
#################################################################

rm(ground)
load("Data/ground_with_nnet.RData")
load("Data/station_new_coords.RData")
ground$Error = ground$Value - ground$Prediction
qplot( ground$Error )
qplot( ground$Error[!ground$outlier] )
qplot( ground$Error[!ground$outlier] ) + xlim(c(-1,1))
qplot(ground$Prediction, ground$Value, geom="smooth")
#ground$Time = ground$Time*1E9
#ground$Time = as.POSIXct(ground$Time, tz="EST", origin=as.POSIXct("1970-01-01", tz="UCT"))
fits = list()
for( prd in list(prd1, prd2, prd3) ){
#for( prd in list(prd2, prd3) ){
  fit = empVario(data=ground[ground$Time %in% unique(tunnel$Time)[prd] & !ground$outlier,]
    ,tlags=0:30, alpha=c(0,45,90,135), varName="Error", boundaries=0:65*10, cutoff=650)
  fits[[length(fits)+1]] = fit
  print(plot.empVario(fit, boundaries=0:65*10, model=F, adj=TRUE))
  save(fits, prd1, prd2, prd3, file="Results/new_sp_variograms_error_short_tlags.RData")
}
save(fits, prd1, prd2, prd3, file="Results/new_sp_variograms_error_short_tlags.RData")

#################################################################
# Space-time modeling: Plots
#################################################################

if(!"Final Variograms" %in% list.files("Results"))
  dir.create("Results/Final Variograms")
files = list.files("Results")
files = files[grepl(".RData", files)]
files = paste0("Results/", files[grepl("new_sp_variograms", files)])
for(file in files){
  load(file)
  #Variogram may be in object fits OR fits.ctl OR fits.test.  Use this if loop to
  #assign the appropriate object to fits
  if(!exists("fits")){
    if(exists("fits.ctl")) fits=fits.ctl
    if(exists("fits.test")) fits=fits.test
  }
  for(i in 1:length(fits)){
    plotName = gsub("Results/", "Results/Final Variograms/", file)
    plotName = gsub(".RData", "", plotName)
    plotName = paste0(plotName, "_prd", i, ".png")
    plotNameIso = gsub("_prd", "_isotropic_prd", plotName)
    png(plotName, width=6, height=10, units="in", res=400)
    plot.empVario(fits[[i]], adj=T, boundaries=0:65*10, scale="fixed")
    dev.off()
    fits[[i]][[1]] = fits[[i]][[1]][fits[[i]][[1]]$dist<500,]
    png(plotNameIso, width=6, height=10, units="in", res=400)
    plot.empVario(fits[[i]], adj=T, boundaries=0:65*10, scale="fixed", rmAni=T)
    dev.off()
  }
  rm(fits, fits.ctl, fits.test)
}

#########################################################################
#Refit model using vgm and fit.StVariogram
#########################################################################

load("Results/new_sp_variograms_error.RData")
load("Results/new_sp_variograms_error_test_only.RData")
load("Results/new_sp_variograms_error_control_only.RData")
plot.empVario(fits.test[[1]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits.ctl[[1]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits[[1]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits.test[[2]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits.ctl[[2]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits[[2]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits.test[[3]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits.ctl[[3]], boundaries=0:65*10, rmAni=T)
plot.empVario(fits[[3]], boundaries=0:65*10, rmAni=T)

fit = fits[[1]]
fit[[1]] = fit[[1]][fit[[1]]$dist<500,]
png("Results/Final Variograms/Pre_Tunneling_Error.png")
plot.empVario(fit, adj=T, boundaries=0:65*10, rmAni=T)
dev.off()

fit = fits[[2]]
fit[[1]] = fit[[1]][fit[[1]]$dist<500,]
png("Results/Final Variograms/Tunneling_Error.png")
plot.empVario(fit, adj=T, boundaries=0:65*10, rmAni=T)
dev.off()

fit = fits[[3]]
fit[[1]] = fit[[1]][fit[[1]]$dist<500,]
png("Results/Final Variograms/Post_Tunneling_Error.png")
plot.empVario(fit, adj=T, boundaries=0:65*10, rmAni=T)
dev.off()



#######################################################################
# Attempt to plot sinusoidal deformation from raw data
#######################################################################

load("Data/ground_for_nnet.RData")
t = unique(ground$Time)
if(!"Sinusoidal Behavior" %in% list.files("Results/"))
  dir.create("Results/Sinusoidal Behavior")
for(i in 1:(length(t)/100)){
  ggsave(paste0("Results/Sinusoidal Behavior/t_",i*100,".png"),
    ggplot(ground[ground$Time==t[i*100],], aes(x=East2, y=North2
          ,color=findInterval(Value, quantile(Value, 0:10/10)))) + 
      geom_point(size=4) +
      labs(color="Decile of\nDeformation")
  )
}

#######################################################################
# Try to understand random and systematic errors in the data
#######################################################################

load("Data/ground_with_nnet.RData")
dir.create("Results/Error Contamination")
#Global Outliers
ggsave("Results/Error Contamination/global_outliers.png",
  ggplot( ground, aes(x=Time, y=Error) ) + geom_point()
)
est = MASS::huber(ground$Error)
ground$score = abs(ground$Error-est$mu)/est$s
qplot( ground$Error[ground$score>5], binwidth=.1 )
qplot( abs(ground$Error[ground$score>5]), binwidth=.1 )
largeErrors = ground$Error[ground$score>5]
save(largeErrors, file="Results/global_outliers.RData")

#Local Outliers
#Idea:  If there are more than 30 consecutive NA's, consider that a lapse in the data.
#Then, compute the difference in means between the pairwise differences.  Save that value
#(i.e. Xbar_l-Xbar_r) as well as the difference statistic: (Xbar_l-Xbar_r)/(sigma_L+sigma_R).
#If statistic surpasses a threshold, call it a changepoint.  Compute the proportion of
#changepoints as well as all the values, then simulate by sampling from these.
load("Data/station_pairs.RData")
ground2 = cast(ground, "Time ~ StationID", value="Error")
shift = NULL
for(i in 1:371){
  s = colnames(ground2)[i+1]
  st_pair = station_pairs[station_pairs$s1==s & station_pairs$s2!=s,]
  neighbor = as.character(st_pair$s2[which.min(st_pair$dist)])
  if(!all(is.na(ground2[,s]/ground2[,neighbor]))){
    ggsave(paste0("Results/Error Contamination/Ratio_Station_",s,"_vs_neighbor.png"),
      qplot( ground2$Time, abs(ground2[,s]/ground2[,neighbor]), geom="line") +
        labs(y="Ratio of Error to nearest neighbor")
    )
    ggsave(paste0("Results/Error Contamination/Diff_Station_",s,"_vs_neighbor.png"),
      qplot( ground2$Time, ground2[,s]-ground2[,neighbor], geom="line") +
        labs(x="", y="Difference of Error from nearest neighbor")
      ,width=5.5, height=5.5
    )
    ggsave(paste0("Results/Error Contamination/Log10_Ratio_Station_",s,"_vs_neighbor.png"),
      qplot( ground2$Time, abs(ground2[,s]/ground2[,neighbor]), geom="line") +
        scale_y_log10("Ratio of Error to nearest neighbor") +
        geom_hline(yintercept=1, color="red", linetype=4) +
        labs(x="")
    )
  }
  
  ts = ground2[,s] - ground2[,neighbor]
  #Search for 30+ consecutive NA's to mark a "lapse"
  naVec = as.numeric(is.na(ts))
  runs = rle(naVec)
  position = cumsum(runs$lengths)
  lapse = runs$values==1 & runs$length>=30
  grp = rep(0,length(naVec))
  grp[position[lapse]] = 1
  grp = cumsum(grp)
  #qplot(1:length(ts), ts, col=factor(grp))
  
  #Compute statistics for each group, consider all breaks
  est = tapply(ts, grp, FUN=function(x){
    if(sum(!is.na(x))<=2)
      return(c(NA,NA,NA))
    est = huber(x)
    return( c(mu=est$mu, s=est$s, n=length(x)) )
  })
  est = do.call("rbind", est)
  for(i in 2:nrow(est) ){
    diff = est[i,"mu"] - est[i-1,"mu"]
    stat = (est[i,"mu"] - est[i-1,"mu"])/sqrt(est[i,"s"]^2/est[i,"n"]+est[i-1,"s"]^2/est[i-1,"n"])
    shift = rbind(shift, data.frame(diff=diff, stat=stat))
  }
}

qplot( abs(shift$stat), binwidth=1, fill=abs(shift$stat)<=5 )
qplot( shift$diff[abs(shift$stat)>20], binwidth=.01 )
qplot( abs(shift$diff[abs(shift$stat)>100]), binwidth=.01 )
sum( abs(shift$stat) > 100, na.rm=T ); sum(!is.na(shift$stat) )
shift = shift[!is.na(shift[,1]),]
save(shift, file="Results/changepoints.RData")
