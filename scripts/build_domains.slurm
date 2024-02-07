#!/bin/bash
#SBATCH --job-name=DOMAINcfg
#SBATCH --time=01:00:00
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks-per-core=1

# Set environment
module load NEMO/prg-env
unset I_MPI_PMI_LIBRARY
export OMP_NUM_THREADS=1

# Link exe
ln -fs ../make_domain_cfg.exe .
ln -fs ../../REBUILD_NEMO/rebuild_nemo{.exe,} .

# Create domains
srun --ntasks="$SLURM_NTASKS" ./make_domain_cfg.exe || exit

# Rebuild
for FILE in *namelist_cfg; do
    STRING=$(basename -- "$FILE")
    PATTERN="domain_cfg"
    PREFIX="${STRING/namelist_cfg/$PATTERN}"
    if ./rebuild_nemo -n nam_rebuild -p "$SLURM_NTASKS" -d 1 -x 64 -y 64 -z 1 -t 1 "$PREFIX" "$SLURM_NTASKS"; then
        rm "${PREFIX}"_[0-9][0-9][0-9][0-9].nc
    else
        rm "$PREFIX".nc
    fi
done

# Bye-Bye
sacct -j "$SLURM_JOB_ID" --units=G --format=JobID,JobName,NNodes,Elapsed,AveRSS,MaxRSS,MaxRSSNode,MaxRSSTask
