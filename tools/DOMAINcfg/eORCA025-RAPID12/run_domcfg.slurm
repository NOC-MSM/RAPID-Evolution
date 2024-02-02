#!/bin/bash
#SBATCH --job-name=DOMCFG
#SBATCH --partition=test
#SBATCH --time=00:20:00
#SBATCH --ntasks=8
#SBATCH --ntasks-per-core=1
#SBATCH --ntasks-per-node=1
#SBATCH --ntasks-per-socket=1
#SBATCH --nodes=8
#SBATCH --mem=240G

# Set environment
module load NEMO/prg-env
export OMP_NUM_THREADS=1
export I_MPI_SHM=off
unset I_MPI_PMI_LIBRARY

# Link exe
ln -fs ../make_domain_cfg.exe .
ln -fs ../../REBUILD_NEMO/rebuild_nemo{.exe,} .

mpiexec.hydra  -print-rank-map -np "$SLURM_NTASKS" ./make_domain_cfg.exe

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
