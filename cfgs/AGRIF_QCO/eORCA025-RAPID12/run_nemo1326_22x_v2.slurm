#!/bin/bash
#SBATCH --job-name=REvo
#SBATCH --partition=test
#SBATCH --time=00:20:00
#SBATCH --ntasks-per-core=1
#SBATCH --ntasks-per-node=64
#SBATCH --ntasks-per-socket=32
#SBATCH --nodes=22
##SBATCH --exclude=compute[001-025]

# ========================================================
# PARAMETERS TO SET
# Restart frequency (<0 days, >0 hours)
FREQRST=-1 #1461
# Simulation length (<0 days, >0 hours)
LENGTH=-5   # 16071 == end of 2001
# Parent initial time step (0: infer from time.step)
# IT000 != 0 -> auto-resubmission is switched OFF
PARENT_IT000=0
# Name of this script (to resubmit)
SCRIPTNAME=run_nemo1326_22x_v2.slurm
# ========================================================

# Define useful functions
get_var () {
    VARNAME=$1
    NAMNAME=$2
    VAR=$(grep "^\s*${VARNAME}\s*=.*" "$NAMNAME" | sed "s/[', ]//g")
    VAR=${VAR%%!*}
    VAR=${VAR#*=}
    echo "$VAR"
}

edit_var () {
    VARNAME=$1
    VAR=$2
    NAMNAMES=${*:3}
    CMD=$(echo sed -i "\"s|^\s*${VARNAME}\s*=.*|\t${VARNAME} = ${VAR},|g\"" "$NAMNAMES")
    eval "$CMD"
}

get_timestep () {
    TIMENAME=$1
    TIMESTEP=$(grep -Eo '[0-9\.]+' "$TIMENAME")
    echo "$TIMESTEP"
}

# Convert days to hours
if [ "$FREQRST" -lt 0 ]; then
    FREQRST=$(( FREQRST * -24 ))
fi
if [ "$LENGTH" -lt 0 ]; then
    LENGTH=$(( LENGTH * -24 ))
fi

# Get parent it000
if [ "$PARENT_IT000" -eq 0 ]; then
    RESUBMIT=true
    if test -f "time.step"; then
        PARENT_IT000=$(get_timestep time.step)
    fi
    PARENT_IT000=$(( PARENT_IT000 + 1 ))
else
    RESUBMIT=false
fi

# Get parent dt
PARENT_DT=$(get_var rn_Dt namelist_cfg)
PARENT_DT=${PARENT_DT%.*}

# Edit namelists
if [ "$PARENT_IT000" -gt 1 ]; then
    # Use restarts
    edit_var ln_rstart ".true." ./*namelist_cfg
    edit_var ln_init_chfrpar ".false." ./*_namelist_cfg
    edit_var ln_tsd_init ".false." ./namelist_cfg

    for NAMELIST in *namelist_cfg; do
        # Set start
        DT=$(get_var rn_Dt "$NAMELIST")
        DT=${DT%.*}
        RATIO=$(( PARENT_DT / DT ))
        TSTEP=$(( (PARENT_IT000 - 1) * RATIO ))
        IT000=$(( TSTEP + 1 / RATIO ))
        edit_var "nn_it000" "$IT000" "$NAMELIST"

        # Set restart prefixes
        EXP=$(get_var cn_exp "${NAMELIST}")
        OCERST_IN=${EXP}_$(printf "%08d" "$TSTEP")_restart
        NAMELIST_ICE=${NAMELIST//namelist_cfg/namelist_ice_cfg}
        ICERST_IN=${OCERST_IN}_ice
        edit_var cn_ocerst_in "'${OCERST_IN}'" "$NAMELIST"
        edit_var cn_icerst_in "'${ICERST_IN}'" "$NAMELIST_ICE"
    done

else
    # Start from rest
    edit_var ln_rstart ".false." ./*namelist_cfg
    edit_var ln_init_chfrpar ".true." ./*_namelist_cfg
    edit_var ln_tsd_init ".true." ./namelist_cfg
    edit_var cn_ocerst_in "'dummy'" ./*namelist_cfg
    edit_var cn_icerst_in "'dummy'" ./*namelist_ice_cfg
    edit_var nn_it000 "1" ./*namelist_cfg
fi

# Edit nn_itend
for NAMELIST in *namelist_cfg; do
    IT000=$(get_var nn_it000 "$NAMELIST")
    DT=$(get_var rn_Dt "$NAMELIST")
    DT=${DT%.*}
    ITEND=$(( IT000 - 1 + FREQRST * 60 * 60 / DT ))
    FINAL=$(( LENGTH * 60 * 60 / DT ))
    if [ "$ITEND" -ge "$FINAL" ]; then
        ITEND=$FINAL
    fi
    edit_var nn_itend "$ITEND" "$NAMELIST"
done

# Submit next job
if [ "$ITEND" -lt "$FINAL" ] && [ "$RESUBMIT" = true ]; then
    sbatch --dependency=afterok:"$SLURM_JOB_ID" "$SCRIPTNAME"
fi

# Create directories
for SUFFIX in RESTARTS OUTPUT; do
    mkdir -p $SUFFIX
    for PREFIX in $(seq "$(find . -name "*_namelist_cfg" | wc -l)"); do
        mkdir -p "${PREFIX}_"$SUFFIX
    done
done

# Link nemo
ln -fs ../BLD/bin/nemo.exe nemo

module load NEMO/prg-env

export XIO_HOME=/home/acc/xios-trunk
#
export OMP_NUM_THREADS=1
export I_MPI_SHM=off
unset I_MPI_PMI_LIBRARY 

#mpiexec.hydra -print-rank-map -ppn 1 -np 24 $XIO_HOME/bin/xios_server.exe : -np 1326 ./nemo
mpiexec.hydra -print-rank-map -ppn 1 -np 22 $XIO_HOME/bin/xios_server.exe : -np 1306 ./nemo

# Move log files
mkdir -p LOGS/"$SLURM_JOB_ID"
mv {*.dat,*output*,*.stat*,communication_report.txt} LOGS/"$SLURM_JOB_ID"

# Check time.step and ocean.output
for NAMELIST in *namelist_cfg; do

    # Check that ocean.output exist
    OUTNAME=${NAMELIST//namelist_cfg/ocean.output}
    OUTNAME=LOGS/"$SLURM_JOB_ID"/"$OUTNAME"
    if [ ! -f  "$OUTNAME" ]; then
        echo "E R R O R : $OUTNAME is missing."
        exit 1
    fi

    # Check for errors
    ERROR=$(grep "E R R O R" "$OUTNAME" | wc -l)
    if [ "$ERROR" -gt 0 ]; then
        echo "E R R O R : errors found in $OUTNAME"
        exit 1
    fi

    # Check that time.step exist
    TIMENAME=${NAMELIST//namelist_cfg/time.step}
    if [ ! -f  "$TIMENAME" ]; then
        echo "E R R O R : $TIMENAME is missing."
        exit 1
    fi

    # Check nn_itend vs time.step
    EXPECTED=$(get_var nn_itend "$NAMELIST")
    ACTUAL=$(get_timestep "$TIMENAME")
    if [ "$ACTUAL" -lt "$EXPECTED" ]; then
        echo "E R R O R : $TIMENAME is $ACTUAL (expecting $EXPECTED)"
        exit 1
    fi
done

