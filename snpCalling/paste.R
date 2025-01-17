#module load intel/18.0 intelmpi/18.0 R/3.6.3; R

args = commandArgs(trailingOnly=TRUE)
job=args[1]
tmpdir=args[2]
method=args[3]

#job=gsub("mitochondrion_genome", "mitochondrionGenome", job)
jobId=gsub(",", "_", job)

### libraries
  library(data.table)
  library(foreach)

### get input files
  files <- list.files(tmpdir, pattern=jobId)
  length(files)
  if(method=="PoolSNP") {
    files <- files[!grepl("SNAPE", files)]
  } else if(method=="SNAPE") {
    files <- files[grepl("SNAPE", files)]
  }
  length(files)

  setwd(tmpdir)

  #files <- files[-1]
### import
  o <- foreach(files.i=files, .errorhandling="pass")%do%{
    #files.i=files[10]
    tmp <- fread(files.i)
    if(dim(tmp)[1]==0) {
      tmp <- data.table(V1=tstrsplit(jobId, "_")[[1]],
                        V2=as.numeric(tstrsplit(jobId, "_")[[2]]):as.numeric(tstrsplit(jobId, "_")[[3]]),
                        V3="N",
                        V4=".:.:.:.:.:.")
    }
    tmp[,pop:=gsub("_$", "", gsub(jobId, "", files.i))]
    tmp
  }
  o <- rbindlist(o, use.names=T, fill=T)
  o[,pop:=gsub(".SNAPE.monomorphic", "", pop)]

  dim(o)
  o[,.N,pop]

### long to wide
  ow <- dcast(o, V1+V2~pop, value.var="V4")

## get reference
  #ow.ref <- o[pop=="MN_BIO1_S1_140711", c("V1", "V2", "V3"), with=F] # replicated runs
  ow.ref <- o[pop=="MN_BIO1_S1", c("V1", "V2", "V3"), with=F]

  setkey(ow, V1, V2)
  setkey(ow.ref, V1, V2)

  owr <- merge(ow.ref, ow)

### output
  write.table(owr, quote=F, row.names=F, col.names=F, sep="\t", file=paste(tmpdir, "/allpops.", method, ".sites", sep=""))
  write.table(names(owr)[-c(1,2,3)], quote=F, row.names=F, col.names=F, sep="\t", file=paste(tmpdir, "/allpops.", method, ".names", sep=""))
