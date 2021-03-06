#-----------------------------------------------------------------------------------
# nested cross-validation 
#                                                                     
# Martin Sill
# m.sill@dkfz.de                                                                  
# 
# 2018-03-14 UTC
#------------------------------------------------------------------------------------                   
#options(max.print = 1000)
#options(stringsAsFactors = FALSE)
#options(scipen = 999)
rm(list=ls())

library(randomForest)
library(parallel)
library(minfi)
library(limma)

ntrees <- 500
cores <- 4
seed <- 180314
p <- 10000
folds <- 3

message("loading filtered Mset ...",Sys.time())
load(file.path("results","Mset_filtered.RData"))

y <- as.factor(anno$`methylation class:ch1`)
batch <- as.factor(anno$`material:ch1`)

source(file.path("R","makefolds.R"))
source(file.path("R","train.R"))
source(file.path("R","calculateCVfold.R"))
source(file.path("R","batchadjust.R"))

if(!file.exists(file.path("CV","nfolds.RData"))){
  dir.create("CV",showWarnings = FALSE)
  nfolds <- makenestedfolds(y,folds)
  save(nfolds,file=file.path("CV","nfolds.RData"))
}
load(file.path("CV","nfolds.RData"))

message("performing nested CV ...", Sys.time())
message("check minimal class sizes for inner training loops")

# check minimal class sizes for inner training loops
minclasssize <- matrix(0,ncol=length(nfolds),nrow=length(nfolds))
for(i in 1:length(nfolds)){
  for(j in 1:length(nfolds))
    minclasssize[i,j]  <- min(table(y[nfolds[[i]][[2]][[j]]$train]))
}
colnames(minclasssize) <- paste0("innfold",1:folds)
rownames(minclasssize) <- paste0("fold",1:folds)
print(minclasssize)

for(K in 1:folds){
  
  for(k in 0:folds){
    
    if(k>0){  message("calculateing fold ",K,".",k,"  ...",Sys.time())
      fold <- nfolds[[K]][[2]][[k]]
    }else{
      message("calculateing outer fold ",K,"  ...",Sys.time())
      fold <- nfolds[[K]][[1]][[1]]
    }
    
    rf.scores <- calcultateCVfold(Mset,y,batch,fold,p,cores,ntrees)
    
    fname <- paste("CVfold",K,k,"RData",sep=".")
    save(rf.scores,file=file.path("CV",fname))
    
    rm(rf.scores)
    gc()
  }
}
message("finished ...",Sys.time())
