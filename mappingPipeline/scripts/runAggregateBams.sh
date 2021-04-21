#!/usr/bin/env bash
#SBATCH --job-name=aggregateBams # A single job name for the array
##SBATCH --ntasks-per-node=10 # one core
#SBATCH -c 3
#SBATCH -N 1 # on one node
#SBATCH -t 00:30:00
#SBATCH --mem 12G
#SBATCH -o /fs/scratch/PAS1715/aphidpool/slurmOutput/aggregateBams.%A_%a.out # Standard output
#SBATCH -e /fs/scratch/PAS1715/aphidpool/slurmOutput/aggregateBams.%A_%a.err # Standard error
#SBATCH --account PAS1715

### modules
  module load singularity

### define a few things
  wd=/fs/scratch/PAS1715/aphidpool
  outputDir=/fs/scratch/PAS1715/aphidpool/dest_mapped/pipeline_output/aggregated
  inputDir=/fs/scratch/PAS1715/aphidpool/dest_mapped/pipeline_output/

### get job number
  pool=$( cat ${wd}/DEST-AglyPoolseq/populationInfo/fieldPools_aggregated.csv | cut -f1,13 -d',' | grep -v "NA" | sed "${SLURM_ARRAY_TASK_ID}q;d" | cut -f1 -d',' )
  
  echo $pool
  
  touch /fs/scratch/PAS1715/aphidpool/dest_mapped/pipeline_output/${pool}_*/${pool}_*.sorted_merged.bam
  
### run aggregateBams.sh
  
  singularity exec aglypoolseq_latest.sif \
  sh DEST-AglyPoolseq/mappingPipeline/scripts/aggregateBams.sh \
  sorted_merged \
  ${inputDir} \
  ${pool} \
  ${outputDir}
