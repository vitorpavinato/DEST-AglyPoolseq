# Various scripts to get DGN data incorporated into DrosEU, DrosRTEC data

## Description
>

## File structure set up

## Parse DGN data ###
  ### 0. Download all DGN data
  > Needs a tab delimited file with jobID, prefix, path to DGN bz2 file: DEST/add_DGN_data/dgn.list
  > Note that job 4 will fail. Why? Because 4 is the fourth line on DGN website for the DSPR. I don't think that we need to include that one.
  > RUN: `sbatch --array=1-8 /scratch/aob2x/dest/DEST/add_DGN_data/downloadDGN.sh`
  > OUT: /scratch/aob2x/dest/dgn/rawData

  ### 1. Unpack
  > RUN: `sbatch --array=6 /scratch/aob2x/dest/DEST/add_DGN_data/unpack.sh`
  > OUT: /scratch/aob2x/dest/dgn/wideData/

  ### 2. Wide to long
  > RUN: `ls /scratch/aob2x/dest/dgn/wideData/ | tr '\t' '\n' | awk '{print NR"\t"$0}' > /scratch/aob2x/dest/dgn/dgn_wideFiles.delim`
  > RUN: `sbatch --array=1-$( tail -n1 /scratch/aob2x/dest/dgn/dgn_wideFiles.delim | cut -f1 ) /scratch/aob2x/dest/DEST/add_DGN_data/wide2long.sh`

  ### 3. Make per-population SYNC file
  > RUN: `ls /scratch/aob2x/dest/dgn/longData/* | rev | cut -f1 -d'/' | rev | cut -f1 -d'_' | sort | uniq | awk '{print NR"\t"$0}' > /scratch/aob2x/dest/dgn/pops.delim`
  > RUN: `sbatch --array-1-$( tail -n1 /scratch/aob2x/dest/dgn/pops.delim | cut -f1 ) /scratch/aob2x/dest/DEST/add_DGN_data/makePopSync.sh`




Convert GDS object back to VCF. Why? Anyway, it also does some filtering and can generate chromosome specific files
  > `sbatch --export=ALL /scratch/aob2x/diapus_gmmat/Diapause_revisions/gmmat_test_scripts/splitGDS.slurm`