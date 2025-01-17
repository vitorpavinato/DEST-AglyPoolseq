##########################################################
#                 POPULATION STRUCTURE                   # 
#       PRNCIPAL COMPONENT ANALYSIS AND CLUSTERING       #
##########################################################

## Vitor Pavinato
## correapavinato.1@osu.edu
## CFAES

###
###
### ---- SETUP ANALYZES ENVIRONMENT ----
###
###

# Recover R-renv environment
setwd("/fs/scratch/PAS1715/aphidpool")

renv::restore()
#renv::snapshot()

# Remove last features
rm(list=ls())
ls()

# Load R libraries
library(data.table)
library(SeqArray)
library(tidyverse)
library(poolfstat)
library(ggpubr)
library(missMDA)
library(ade4)
library(factoextra)
library(zoo)
library(FactoMineR)
library(Hmisc)

setwd("/fs/project/PAS1554/aphidpool/")
# Import auxiliary R functions
source("AglyPoolseq/analyses/aggregated_data/ThinLDinR_SNPtable.R")
source("AglyPoolseq/analyses/aggregated_data/aux_func.R")

### FOR COLORS
ALPHA=0.75

###
###
### ---- SETUP THE DATASET INFORMATION ----
###
###

#### PoolSNPs - Poolfstat Analyses Dataset:
#### Dataset 2: 24-Jun-2021; Min_cov=4; Max_cov=0.99; MAF=0.05; MAC=5; 21 pools; miss_fraction=0.50
#### vcf/aggregated_data/minmaxcov_4_99/aphidpool.PoolSeq.PoolSNP.05.5.24Jun2021.vcf.gz

### POOL'S INFORMATION
## Pool's sizes
poolsizes <- rep(10,21)

## Pool's names
poolnames <- c("MN-Av.1", "MN-V.1",
               "ND-Av.1", "ND-V.1", 
               "NW-Av.1", "NW-Av.2", "NW-V.1", "NW-V.2", "NW-V.3", 
               "PA-Av.1", "PA-V.1", "PA-V.2", 
               "WI-Av.1", "WI-Av.2", "WI-V.1", "WI-V.2", "WI-V.3", 
               "WO-Av.1", "WO-V.1", "WO-V.2", "WO-V.3")

## Pool's/biotypes colors - for PCA
biotype.col <- c("#247F00","#AB1A53",
                 "#247F00","#AB1A53",
                 "#247F00","#247F00","#AB1A53","#AB1A53","#AB1A53",
                 "#247F00","#AB1A53","#AB1A53",
                 "#247F00","#247F00","#AB1A53","#AB1A53","#AB1A53",
                 "#247F00","#AB1A53","#AB1A53","#AB1A53")
## Biotype symbols
biotype.sym <- c(15,17,
                 15,17,
                 15,15,17,17,17,
                 15,17,17,
                 15,15,17,17,17,
                 15,17,17,17)

###
###
### ---- STEPS TO PREPARE THE PCA DATASET ----
###
###

### 1- Upload gds dataset;
### 2- Calculate sequencing error rate - % of > 3-allelic SNPs; Remove SNPs with > 2 alleles;
### 3- Remove samples if necessary (biotypes dataset);
### 4- Remove variants with > 5% missing genotypes;
### 5- Remove linked SNPs - SNPs within 500bp window;
### 6- Export gds to vcf;
### 7- Import the vcf with Poolfstat

### open GDS file
genofile <- seqOpen("vcf/aggregated_data/minmaxcov_4_99/aphidpool.PoolSeq.PoolSNP.05.5.24Jun2021.ann.gds")
seqResetFilter(genofile)

###
###
### ---- PART 1: PCA FOR ALL POOLS ----
###
###

### make a copy for the pools dataset
genofile.pools <- genofile

### get subsample of data to work on
seqResetFilter(genofile.pools)

snps.dt.pools <- data.table(chr=seqGetData(genofile.pools, "chromosome"),
                            pos=seqGetData(genofile.pools, "position"),
                            variant.id=seqGetData(genofile.pools, "variant.id"),
                            nAlleles=seqNumAllele(genofile.pools),
                            missing=seqMissing(genofile.pools, .progress=T))

### Calculate sequencing error rate (approximate with % > 2-allelic SNPs)
total_snps <- length(snps.dt.pools$variant.id)
trialle_snps <- length(snps.dt.pools$variant.id[snps.dt.pools$nAlleles > 2])

(trialle_snps/total_snps)*100
# 0.8969094

### choose number of alleles
snps.dt.pools <- snps.dt.pools[nAlleles==2]

### Apply filter
seqSetFilter(genofile.pools, variant.id=snps.dt.pools$variant.id)

### select sites with missing fraction < 0.05
seqSetFilter(genofile.pools,
             snps.dt.pools[missing<.05]$variant.id)


snps.dt.pools <- data.table(chr=seqGetData(genofile.pools, "chromosome"),
                            pos=seqGetData(genofile.pools, "position"),
                            variant.id=seqGetData(genofile.pools, "variant.id"),
                            nAlleles=seqNumAllele(genofile.pools),
                            missing=seqMissing(genofile.pools, .progress=T))


### Remove Physical Linkage - one SNP every 500bp
snp_info.pools = data.frame(chr=as.character(snps.dt.pools$chr), pos=as.numeric(snps.dt.pools$pos))

picksnps_500.pools <- pickSNPs(snp_info.pools,dist=500)

snps.dt.pools <- snps.dt.pools[picksnps_500.pools,] 

### Apply filter
seqSetFilter(genofile.pools, variant.id=snps.dt.pools$variant.id)

### FILTER SNPS FOR ALL SAMPLES
seqGDS2VCF(genofile.pools, 
           vcf.fn= "vcf/aggregated_data/minmaxcov_4_99/aphidpool.PoolSeq.PoolSNP.05.5.24Jun2021.ann.filtered.pools.vcf", 
           info.var=NULL, fmt.var=NULL, verbose=TRUE)


### IMPORT FILTERED VCF WITH POOLFSTAT
dt.1.flt.pools <- vcf2pooldata(
                               vcf.file = "vcf/aggregated_data/minmaxcov_4_99/aphidpool.PoolSeq.PoolSNP.05.5.24Jun2021.ann.filtered.pools.vcf",
                               poolsizes = poolsizes,
                               poolnames = poolnames,
                               min.cov.per.pool = -1,
                               min.rc = 1,
                               max.cov.per.pool = 1e+06,
                               min.maf = 0.05,
                               remove.indels = FALSE,
                               nlines.per.readblock = 1e+06
)
dt.1.flt.pools

### COMPUTE MAXIMUM LIKELIHOOD IMPUTED SAMPLE ALLELE COUNT
dt.1.flt.pools.imputedRefMLCount <- imputedRefMLCount(dt.1.flt.pools)
dt.1.flt.pools.imputedRefMLFreq <- dt.1.flt.pools.imputedRefMLCount[[1]]/dt.1.flt.pools.imputedRefMLCount[[3]]

### ---- PRINCIPAL COMPONENT ANALYSIS PRICE ET AL. 2010 ----
W_pools <- scale(t(dt.1.flt.pools.imputedRefMLFreq), scale=TRUE) #centering
W_pools[1:10,1:10]
W_pools[is.na(W_pools)]<-0
cov.W_pools<-cov(t(W_pools))
eig.result_pools<-eigen(cov.W_pools)
eig.vec_pools<-eig.result_pools$vectors
lambda_pools<-eig.result_pools$values

## PVE
par(mar=c(5,5,4,1)+.1)
plot(lambda_pools/sum(lambda_pools),ylab="Fraction of total variance", ylim=c(0,0.1), type='b', cex=1.1,
     cex.lab=1.6, pch=19, col="black")
lines(lambda_pools/sum(lambda_pools), col="red")

l1_pools <- 100*lambda_pools[1]/sum(lambda_pools) 
l2_pools <- 100*lambda_pools[2]/sum(lambda_pools)

## PCA plot
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_pools.pdf",         # File name
    width = 11, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)
par(mar=c(5,5,4,1)+.1)
plot(eig.vec_pools[,1],eig.vec_pools[,2], col=biotype.col,
     xlim = c(-0.75, 0.45), ylim = c(-0.35, 0.65),
     xlab=paste0("PC1 (", round(l1_pools,2), "%)"), ylab=paste0("PC1 (", round(l2_pools,2), "%)"), 
     cex=1.5, pch=19, cex.lab=1.6)
text(eig.vec_pools[,1],eig.vec_pools[,2], 
     poolnames, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = 19, bty = "n", cex = 1.1)
abline(v=0,h=0,col="grey",lty=3)
dev.off()

### ---- PRINCIPAL COMPONENT ANALYSIS WITH FactorMineR ----

### Convert NA cells into loci means
dt.1.flt.pools.NAimputed = na.aggregate(t(dt.1.flt.pools.imputedRefMLFreq))

### PCA
pca.dt.1.flt.pools <- PCA(dt.1.flt.pools.NAimputed, scale.unit = F, graph = F)

barplot(pca.dt.1.flt.pools$eig[,1],main="Eigenvalues",names.arg=1:nrow(pca.dt.1.flt.pools$eig))
summary(pca.dt.1.flt.pools)

### Run cluster analysis
## 1. Loading and preparing data
pca.dt.1.flt.pools.ind_coord <- pca.dt.1.flt.pools$ind$coord

cluster_discovery_pools = fviz_nbclust(pca.dt.1.flt.pools.ind_coord, kmeans, method = "gap_stat")

# 2. Compute k-means at K=2, K=3 and at K=4
set.seed(123)
kmeans_k2_pools <- kmeans(pca.dt.1.flt.pools.ind_coord, 2, nstart = 20)
kmeans_k3_pools <- kmeans(pca.dt.1.flt.pools.ind_coord, 3, nstart = 20)
kmeans_k4_pools <- kmeans(pca.dt.1.flt.pools.ind_coord, 4, nstart = 20)
kmeans_k5_pools <- kmeans(pca.dt.1.flt.pools.ind_coord, 5, nstart = 20)

# Combine Pool ID with cluster assigment
data.frame(k2_clusters = kmeans_k2_pools$cluster,
           k3_clusters = kmeans_k3_pools$cluster,
           k4_clusters = kmeans_k4_pools$cluster,
           k5_clusters = kmeans_k5_pools$cluster) %>% mutate(sampleId = poolnames) -> pca.dt.1.flt.pools_cluster_data

### COMBINED PCA PLOTS
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_factorminer_clusters_pools.pdf",         # File name
    width = 11, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)

par(mar=c(5,5,4,1)+.1, mfrow=c(2, 2))
# PLOT PCA COLORED BY BIOTYPE
plot(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], col=biotype.col,
     xlim = c(-2.4, 2.5), ylim = c(-2, 3), main="K=1",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], 
     pca.dt.1.flt.pools_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = c(15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K2
plot(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], col=pca.dt.1.flt.pools_cluster_data$k2_clusters,
     xlim = c(-2.4, 2.5), ylim = c(-2, 3),  main="K=2",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], 
     pca.dt.1.flt.pools_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2", "Avirulent", "Virulent"), col = c(1,2, "grey", "grey"), 
       pch = c(19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K3
plot(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], col=pca.dt.1.flt.pools_cluster_data$k3_clusters,
     xlim = c(-2.4, 2.5), ylim = c(-2, 3), main="K=3",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], 
     pca.dt.1.flt.pools_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2","K3", "Avirulent", "Virulent"), col = c(1,2,3, "grey", "grey"), 
       pch = c(19,19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K4
plot(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], col=pca.dt.1.flt.pools_cluster_data$k4_clusters,
     xlim = c(-2.4, 2.5), ylim = c(-2, 3), main="K=4",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], 
     pca.dt.1.flt.pools_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2","K3","K4", "Avirulent", "Virulent"), col = c(1,2,3,4, "grey", "grey"), 
       pch = c(19,19,19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)
dev.off()

## Savepoint_1
##-------------
#save.image("/fs/scratch/PAS1715/aphidpool/results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/clustering.poolsnp.workspace29Jul21.RData.RData")
#load("/fs/scratch/PAS1715/aphidpool/results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/clustering.poolsnp.workspace29Jul21.RData.RData")
############## END THIS PART

###
###
### ---- PART 2: PCA FOR BIOTYPES ----
###
###

### make a copy for only biotypes samples dataset
genofile.biotypes <- genofile

### get subsample of data to work on
seqResetFilter(genofile.biotypes)

### get target populations
biotype.pools2keep <- c(1, 2, 3, 4, 6, 7, 10,11,14,16,18,20)
samps <- seqGetData(genofile.biotypes, "sample.id")
samps <- samps[biotype.pools2keep]

seqSetFilter(genofile.biotypes, sample.id=samps)

snps.dt.biotypes <- data.table(chr=seqGetData(genofile.biotypes, "chromosome"),
                               pos=seqGetData(genofile.biotypes, "position"),
                               variant.id=seqGetData(genofile.biotypes, "variant.id"),
                               nAlleles=seqNumAllele(genofile.biotypes),
                               missing=seqMissing(genofile.biotypes, .progress=T))

### Calculate sequencing error rate (approximate with % > 2-allelic SNPs)
total_snps.biotypes <- length(snps.dt.biotypes$variant.id)
trialle_snps.biotypes <- length(snps.dt.biotypes$variant.id[snps.dt.biotypes$nAlleles > 2])

(trialle_snps.biotypes/total_snps.biotypes)*100
# 0.8969094

### choose number of alleles
snps.dt.biotypes <- snps.dt.biotypes[nAlleles==2]

### Apply filter
seqSetFilter(genofile.biotypes, sample.id=samps, variant.id=snps.dt.biotypes$variant.id)

### select sites with missing fraction < 0.05
seqSetFilter(genofile.biotypes,
             snps.dt.biotypes[missing<.05]$variant.id)

snps.dt.biotypes <- data.table(chr=seqGetData(genofile.biotypes, "chromosome"),
                               pos=seqGetData(genofile.biotypes, "position"),
                               variant.id=seqGetData(genofile.biotypes, "variant.id"),
                               nAlleles=seqNumAllele(genofile.biotypes),
                               missing=seqMissing(genofile.biotypes, .progress=T))

### Remove Physical Linkage - one SNP every 500bp
snp_info.biotypes = data.frame(chr=as.character(snps.dt.biotypes$chr), pos=as.numeric(snps.dt.biotypes$pos))

picksnps_500.biotypes<- pickSNPs(snp_info.biotypes,dist=500)

snps.dt.biotypes <- snps.dt.biotypes[picksnps_500.biotypes,] 

### Apply filter
seqSetFilter(genofile.biotypes, sample.id=samps, variant.id=snps.dt.biotypes$variant.id)

### FILTER SNPS FOR ALL SAMPLES
seqGDS2VCF(genofile.biotypes, 
           vcf.fn= "vcf/aggregated_data/minmaxcov_4_99/aphidpool.PoolSeq.PoolSNP.05.5.24Jun2021.ann.filtered.biotypes.vcf", 
           info.var=NULL, fmt.var=NULL, verbose=TRUE)


### IMPORT VCF WITH POOLFSTAT
dt.1.flt.biotypes <- vcf2pooldata(
                                  vcf.file = "vcf/aggregated_data/minmaxcov_4_99/aphidpool.PoolSeq.PoolSNP.05.5.24Jun2021.ann.filtered.biotypes.vcf",
                                  poolsizes = poolsizes[biotype.pools2keep],
                                  poolnames = poolnames[biotype.pools2keep],
                                  min.cov.per.pool = -1,
                                  min.rc = 1,
                                  max.cov.per.pool = 1e+06,
                                  min.maf = 0.05,
                                  remove.indels = FALSE,
                                  nlines.per.readblock = 1e+06
)
dt.1.flt.biotypes

### COMPUTE MAXIMUM LIKELIHOOD IMPUTED SAMPLE ALLELE COUNT
dt.1.flt.biotypes.imputedRefMLCount <- imputedRefMLCount(dt.1.flt.biotypes)
dt.1.flt.biotypes.imputedRefMLFreq <- dt.1.flt.biotypes.imputedRefMLCount[[1]]/dt.1.flt.biotypes.imputedRefMLCount[[3]]

### ---- PRINCIPAL COMPONENT ANALYSIS PRICE ET AL. 2010 ----
W_biotypes <- scale(t(dt.1.flt.biotypes.imputedRefMLFreq), scale=TRUE) #centering
W_biotypes[1:10,1:10]
W_biotypes[is.na(W_biotypes)]<-0
cov.W_biotypes<-cov(t(W_biotypes))
eig.result_biotypes<-eigen(cov.W_biotypes)
eig.vec_biotypes<-eig.result_biotypes$vectors
lambda_biotypes<-eig.result_biotypes$values

## PVE
par(mar=c(5,5,4,1)+.1)
plot(lambda_biotypes/sum(lambda_biotypes),ylab="Fraction of total variance", ylim=c(0,0.2), type='b', cex=1.1,
     cex.lab=1.6, pch=19, col="black")
lines(lambda_biotypes/sum(lambda_biotypes), col="red")

l1_biotypes <- 100*lambda_biotypes[1]/sum(lambda_biotypes) 
l2_biotypes <- 100*lambda_biotypes[2]/sum(lambda_biotypes)

## PCA plot
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_biotypes.pdf",         # File name
    width = 11, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)
par(mar=c(5,5,4,1)+.1)
plot(eig.vec_biotypes[,1],eig.vec_biotypes[,2], col=biotype.col[biotype.pools2keep],
     xlim = c(-0.75, 0.45), ylim = c(-0.35, 0.65),
     xlab=paste0("PC1 (", round(l1_biotypes,2), "%)"), ylab=paste0("PC1 (", round(l2_biotypes,2), "%)"), 
     cex=1.5, pch=19, cex.lab=1.6)
text(eig.vec_biotypes[,1],eig.vec_biotypes[,2], 
     poolnames[biotype.pools2keep], pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = 19, bty = "n", cex = 1.1)
abline(v=0,h=0,col="grey",lty=3)
dev.off()

### ---- PRINCIPAL COMPONENT ANALYSIS WITH FactorMineR ----

### Convert NA cells into loci means
dt.1.flt.biotypes.NAimputed = na.aggregate(t(dt.1.flt.biotypes.imputedRefMLFreq))

### PCA
pca.dt.1.flt.biotypes <- PCA(dt.1.flt.biotypes.NAimputed, scale.unit = F, graph = F)

barplot(pca.dt.1.flt.biotypes$eig[,1],main="Eigenvalues",names.arg=1:nrow(pca.dt.1.flt.biotypes$eig))
summary(pca.dt.1.flt.biotypes)

### Run cluster analysis
## 1. Loading and preparing data
pca.dt.1.flt.biotypes.ind_coord <- pca.dt.1.flt.biotypes$ind$coord

cluster_discovery_biotypes = fviz_nbclust(pca.dt.1.flt.biotypes.ind_coord, kmeans, method = "gap_stat")

# 2. Compute k-means at K=2, K=3 and at K=4
set.seed(123)
kmeans_k2_biotypes <- kmeans(pca.dt.1.flt.biotypes.ind_coord, 2, nstart = 20)
kmeans_k3_biotypes <- kmeans(pca.dt.1.flt.biotypes.ind_coord, 3, nstart = 20)
kmeans_k4_biotypes <- kmeans(pca.dt.1.flt.biotypes.ind_coord, 4, nstart = 20)
kmeans_k5_biotypes <- kmeans(pca.dt.1.flt.biotypes.ind_coord, 5, nstart = 20)

# Combine Pool ID with cluster assigment
data.frame(k2_clusters = kmeans_k2_biotypes$cluster,
           k3_clusters = kmeans_k3_biotypes$cluster,
           k4_clusters = kmeans_k4_biotypes$cluster,
           k5_clusters = kmeans_k5_biotypes$cluster) %>% mutate(sampleId = poolnames[biotype.pools2keep]) -> pca.dt.1.flt.biotypes_cluster_data

### COMBINED PCA PLOTS
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_factorminer_clusters_biotypes.pdf",         # File name
    width = 11, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)

par(mar=c(5,5,4,1)+.1, mfrow=c(2, 2))
# PLOT PCA COLORED BY BIOTYPE
plot(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], col=biotype.col[biotype.pools2keep],
     xlim = c(-2.0, 2.9), ylim = c(-2.4, 2.2), main="K=1",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym[biotype.pools2keep])
text(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], 
     pca.dt.1.flt.biotypes_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = c(15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K2
plot(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], col=pca.dt.1.flt.biotypes_cluster_data$k2_clusters,
     xlim = c(-2.0, 2.9), ylim = c(-2.4, 2.2),  main="K=2",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym[biotype.pools2keep])
text(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], 
     pca.dt.1.flt.biotypes_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2", "Avirulent", "Virulent"), col = c(1,2, "grey", "grey"), 
       pch = c(19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K3
plot(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], col=pca.dt.1.flt.biotypes_cluster_data$k3_clusters,
     xlim = c(-2.0, 2.9), ylim = c(-2.4, 2.2), main="K=3",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym[biotype.pools2keep])
text(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], 
     pca.dt.1.flt.biotypes_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2","K3", "Avirulent", "Virulent"), col = c(1,2,3, "grey", "grey"), 
       pch = c(19,19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K4
plot(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], col=pca.dt.1.flt.biotypes_cluster_data$k4_clusters,
     xlim = c(-2.0, 2.9), ylim = c(-2.4, 2.2), main="K=4",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym[biotype.pools2keep])
text(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], 
     pca.dt.1.flt.biotypes_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2","K3","K4", "Avirulent", "Virulent"), col = c(1,2,3,4, "grey", "grey"), 
       pch = c(19,19,19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)
dev.off()

## Savepoint_2
##-------------
#save.image("/fs/scratch/PAS1715/aphidpool/results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/clustering.poolsnp.workspace29Jul21.RData.RData")
#load("/fs/scratch/PAS1715/aphidpool/results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/clustering.poolsnp.workspace29Jul21.RData.RData")
############## END THIS PART

###
###
### ---- PART 4: COMBINE POOLS AND BIOTYPES FACTOR MINER PCA ----
###
###

### COMBINED PCA PLOTS
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_factorminer_pca_poolsBiotypes.pdf",         # File name
    width = 16, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)

par(mar=c(5,5,4,1)+.1, mfrow=c(1, 2))
# POOLS: PLOT PCA COLORED BY BIOTYPE
plot(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], col=biotype.col,
     xlim = c(-2.4, 2.5), ylim = c(-2, 3), main="21 samples",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.pools$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.pools$svd$U[,1], pca.dt.1.flt.pools$svd$U[,2], 
     pca.dt.1.flt.pools_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = c(15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# BIOTYPES: PLOT PCA COLORED BY BIOTYPE
plot(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], col=biotype.col[biotype.pools2keep],
     xlim = c(-2.0, 2.9), ylim = c(-2.4, 2.2), main="12 samples (biotypes)",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.biotypes$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym[biotype.pools2keep])
text(pca.dt.1.flt.biotypes$svd$U[,1], pca.dt.1.flt.biotypes$svd$U[,2], 
     pca.dt.1.flt.biotypes_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = c(15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)
dev.off()

#  COMBINED CLUSTER DISCOVERY GAP STATISTICS PLOTS
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_factorminer_clusDisc_poolsBiotypes.pdf",         # File name
    width = 16, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)
par(mar=c(5,5,4,1)+.1, mfrow=c(1, 2))
# POOLS: PLOT PCA COLORED BY BIOTYPE
errbar(seq(1,10), 
       cluster_discovery_pools$data$gap,
       cluster_discovery_pools$data$ymax,
       cluster_discovery_pools$data$ymin,
       type='b', pch=19, ylim=c(-0.05, 0.60),
       ylab="Gap statistics (k)", xlab="Number of clusters k", cex.lab=1.6, cex.axis=1.4)
abline(v=1, col="#b2182b", lty=3, lwd=2)
text(x=2.8, y=0.6,  pos=1, "Optimal number of clusters", col="#b2182b",cex=1.2)

# BIOTYPES: PLOT PCA COLORED BY BIOTYPE
errbar(seq(1,10), 
       cluster_discovery_biotypes$data$gap,
       cluster_discovery_biotypes$data$ymax,
       cluster_discovery_biotypes$data$ymin,
       type='b', pch=19, ylim=c(-0.05, 0.60),
       ylab="Gap statistics (k)", xlab="Number of clusters k", cex.lab=1.6, cex.axis=1.4)
abline(v=1, col="#b2182b", lty=3, lwd=2)
text(x=2.8, y=0.6, pos=1, "Optimal number of clusters", col="#b2182b",cex=1.2)
dev.off()

## Savepoint_3
##-------------
#save.image("/fs/scratch/PAS1715/aphidpool/results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/clustering.poolsnp.workspace29Jul21.RData.RData")
#load("/fs/project/PAS1554/aphidpool/results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/clustering.poolsnp.workspace29Jul21.RData.RData")
############## END THIS PART


###
###
### ---- EXPERIMENTAL: PCA ANALYZES WITH AVERAGE ALLELE FREQUENCIES ----
###
###

### The goal with these analyzes is to check any missing signal by using samples within locations
### For locations we have >1 sample per biotype, take the average allele frequency
### At the end, we have 12 pools (populations); 1 for each biotype/location.

## New biotype tags
new.poolnames <- c("MN-Av", "MN-V",
                   "ND-Av", "ND-V", 
                   "NW-Av", "NW-V", 
                   "PA-Av", "PA-V", 
                   "WI-Av", "WI-V", 
                   "WO-Av", "WO-V")

## New biotypes colors - for PCA
new.biotype.col <- c(rep(c("#247F00","#AB1A53"), 6))

## Biotype symbols
new.biotype.sym <- c(rep(c(15,17), 6))

### TAKE THE ONES THAT DON'T NEED BE AVERAGED
mn_av <- dt.1.flt.pools.imputedRefMLFreq[,1]
mn_v  <- dt.1.flt.pools.imputedRefMLFreq[,2]
nd_av <- dt.1.flt.pools.imputedRefMLFreq[,3]
nd_v  <- dt.1.flt.pools.imputedRefMLFreq[,4]
pa_av <-  dt.1.flt.pools.imputedRefMLFreq[,10]
wo_av <-  dt.1.flt.pools.imputedRefMLFreq[,18]

### TAKE THE AVERAGE ALLELE FREQUENCIES FOR POPULATIONS THAT HAVE SAMPLES-WITHIN
nw_av <- rowMeans(dt.1.flt.pools.imputedRefMLFreq[,5:6], na.rm = T)
nw_v <- rowMeans(dt.1.flt.pools.imputedRefMLFreq[,7:9], na.rm = T)
pa_v <- rowMeans(dt.1.flt.pools.imputedRefMLFreq[,11:12], na.rm = T)
wi_av <- rowMeans(dt.1.flt.pools.imputedRefMLFreq[,13:14], na.rm = T)
wi_v <- rowMeans(dt.1.flt.pools.imputedRefMLFreq[,15:17], na.rm = T)
wo_v <- rowMeans(dt.1.flt.pools.imputedRefMLFreq[,19:21], na.rm = T)

dt.1.flt.pools.imputedRefMLFreq.avg <- cbind(mn_av, mn_v,
                                             nd_av, nd_v,
                                             nw_av, nw_v,
                                             pa_av, pa_v,
                                             wi_av, wi_v,
                                             wo_av, wo_v)

### ---- PRINCIPAL COMPONENT ANALYSIS PRICE ET AL. 2010 ----
W_avrg <- scale(t(dt.1.flt.pools.imputedRefMLFreq.avg), scale=TRUE) #centering
W_avrg[1:10,1:10]
W_avrg[is.na(W_avrg)]<-0
cov.W_avrg<-cov(t(W_avrg))
eig.result_avrg<-eigen(cov.W_avrg)
eig.vec_avrg<-eig.result_avrg$vectors
lambda_avrg<-eig.result_avrg$values

## PVE
par(mar=c(5,5,4,1)+.1)
plot(lambda_avrg/sum(lambda_avrg),ylab="Fraction of total variance", ylim=c(0,0.2), type='b', cex=1.1,
     cex.lab=1.6, pch=19, col="black")
lines(lambda_avrg/sum(lambda_avrg), col="red")

l1_avrg <- 100*lambda_avrg[1]/sum(lambda_avrg) 
l2_avrg <- 100*lambda_avrg[2]/sum(lambda_avrg)

## PCA plot
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_pools_avrg.pdf",         # File name
    width = 11, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)
par(mar=c(5,5,4,1)+.1)
plot(eig.vec_avrg[,1],eig.vec_avrg[,2], col=new.biotype.col,
     xlim = c(-0.95, 0.3), ylim = c(-0.75, 0.75),
     xlab=paste0("PC1 (", round(l1_avrg,2), "%)"), ylab=paste0("PC1 (", round(l2_avrg,2), "%)"), 
     cex=1.5, pch=new.biotype.sym, cex.lab=1.6)
text(eig.vec_avrg[,1],eig.vec_avrg[,2], 
     new.poolnames, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = new.biotype.sym[1:2], bty = "n", cex = 1.1)
abline(v=0,h=0,col="grey",lty=3)
dev.off()

### ---- PRINCIPAL COMPONENT ANALYSIS WITH FactorMineR ----

### Convert NA cells into loci means
dt.1.flt.pools.NAimputed_avrg = na.aggregate(t(dt.1.flt.pools.imputedRefMLFreq.avg))

### PCA
pca.dt.1.flt.avrg <- PCA(dt.1.flt.pools.NAimputed_avrg, scale.unit = F, graph = F)

barplot(pca.dt.1.flt.avrg$eig[,1],main="Eigenvalues",names.arg=1:nrow(pca.dt.1.flt.avrg$eig))
summary(pca.dt.1.flt.avrg)

### Run cluster analysis
## 1. Loading and preparing data
pca.dt.1.flt.avrg.ind_coord <- pca.dt.1.flt.avrg$ind$coord

cluster_discovery_avrg = fviz_nbclust(pca.dt.1.flt.avrg.ind_coord, kmeans, method = "gap_stat")

# 2. Compute k-means at K=2, K=3 and at K=4
set.seed(123)
kmeans_k2_avrg <- kmeans(pca.dt.1.flt.avrg.ind_coord, 2, nstart = 20)
kmeans_k3_avrg <- kmeans(pca.dt.1.flt.avrg.ind_coord, 3, nstart = 20)
kmeans_k4_avrg <- kmeans(pca.dt.1.flt.avrg.ind_coord, 4, nstart = 20)
kmeans_k5_avrg <- kmeans(pca.dt.1.flt.avrg.ind_coord, 5, nstart = 20)

# Combine Pool ID with cluster assigment
data.frame(k2_clusters = kmeans_k2_avrg$cluster,
           k3_clusters = kmeans_k3_avrg$cluster,
           k4_clusters = kmeans_k4_avrg$cluster,
           k5_clusters = kmeans_k5_avrg$cluster) %>% mutate(sampleId = new.poolnames) -> pca.dt.1.flt.avrg_cluster_data

### COMBINED PCA PLOTS
pdf("results/aggregated_data/minmaxcov_4_99/clustering_poolsnp/pca_imputed_allelefreq_filtered_snps_factorminer_clusters_pools_avrg.pdf",         # File name
    width = 11, height = 8.50, # Width and height in inches
    bg = "white",          # Background color
    colormodel = "cmyk",    # Color model (cmyk is required for most publications)
)

par(mar=c(5,5,4,1)+.1, mfrow=c(2, 2))
# PLOT PCA COLORED BY BIOTYPE
plot(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], col=biotype.col,
     xlim = c(-2.4, 3.5), ylim = c(-2.5, 3), main="K=1",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], 
     pca.dt.1.flt.avrg_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("Avirulent", "Virulent"), col = c("#247F00","#AB1A53"), 
       pch = c(15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K2
plot(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], col=pca.dt.1.flt.avrg_cluster_data$k2_clusters,
     xlim = c(-2.4, 3.5), ylim = c(-2.5, 3),  main="K=2",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], 
     pca.dt.1.flt.avrg_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2", "Avirulent", "Virulent"), col = c(1,2, "grey", "grey"), 
       pch = c(19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K3
plot(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], col=pca.dt.1.flt.avrg_cluster_data$k3_clusters,
     xlim = c(-2.4, 3.5), ylim = c(-2.5, 3), main="K=3",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], 
     pca.dt.1.flt.avrg_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2","K3", "Avirulent", "Virulent"), col = c(1,2,3, "grey", "grey"), 
       pch = c(19,19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)

# PLOT PCA COLORED BY K4
plot(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], col=pca.dt.1.flt.avrg_cluster_data$k4_clusters,
     xlim = c(-2.4, 3.5), ylim = c(-2.5, 3), main="K=4",
     xlab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[1,2],2), "%)"), 
     ylab=paste0("PC1 (", round(pca.dt.1.flt.avrg$eig[2,2],2), "%)"), 
     cex=1.7, pch=biotype.sym)
text(pca.dt.1.flt.avrg$svd$U[,1], pca.dt.1.flt.avrg$svd$U[,2], 
     pca.dt.1.flt.avrg_cluster_data$sampleId, pos=2 , cex = 0.6)
legend("topleft", 
       legend = c("K1", "K2","K3","K4", "Avirulent", "Virulent"), col = c(1,2,3,4, "grey", "grey"), 
       pch = c(19,19,19,19,15,17), bty = "n", cex = 1.2)
abline(v=0,h=0,col="grey",lty=3)
dev.off()

