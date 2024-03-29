#!/bin/bash
#SBATCH --job-name=WEIGHTS
#SBATCH --time=01:00:00
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks-per-core=1

# Use --multi-prog
USE_MULTI_PROG=false

# Link exe
ln -fs ../{scripgrid,scrip,scripshape}.exe .

# Set environment
module load NEMO/prg-env
unset I_MPI_PMI_LIBRARY


# Set variables and create directories
TMPDIR=TMP-$SLURM_JOB_ID
TASKNAME=task-$SLURM_JOB_ID.conf
mkdir -p WEIGHTS/JRA "$TMPDIR"
echo -n > "$TASKNAME"

# Create task script
cat << EOF > task.sh
#!/bin/bash

# Set variables
NAMELIST=\$1
OUTFILE=\$2

# Create weights
for EXE in scripgrid.exe scrip.exe scripshape.exe; do
    echo Creating "\${OUTFILE}": "\${EXE}"
    ./\$EXE "\$NAMELIST" || exit
done

# Chunk and compress
echo Compressing and chunking "\${OUTFILE}"
ncks -4 --no_abc --cnk_dmn lon,64 --cnk_dmn lat,64 --dfl_lvl 1 "\${OUTFILE}" -O "\${OUTFILE}"
EOF
chmod u+x task.sh

# Create namelists and task.conf
NTASKS=0
for INFILE in sss_1m_teos10_v4.2 Goutorbe_ghflux.nc JRA/tas_y2021 JRA/vas_y2021 merged_ESACCI_BIOMER4V1R1_CHL_REG05 zdfiwm_forcing_regular EN.4.1.1.f.analysis.g10.1995-2014.eORCA12.SSS.teos10_R12.nc EN.4.1.1.f.analysis.g10.1995-2014.eORCA12.salinity.teos10_R12.nc EN.4.1.1.f.analysis.g10.1995-2014.eORCA12.temperature.teos10_R12.nc eORCA12_runoff_v2.4_GO6_ICB_R12.nc 1_bfr_coef.nc 1_shlat2d_eORCA12_southps_R12.nc ; do
    BASENAME=$(basename $INFILE)

    # Set coordinate names
    if [ "$INFILE" = "sss_1m" ] || [ "$INFILE" = "runoff_1m_nomask" ]; then
        LON=nav_lon
        LAT=nav_lat
    else
        LON=lon
        LAT=lat
    fi

    # Set interpolation method
    if [ "$BASENAME" = "vas_y2021" ]; then
        METHOD=bicubic
    else
        METHOD=bilinear
    fi

    # Set filenames
    NAMELIST=$TMPDIR/namelist-$BASENAME
    if [ "$BASENAME" = "tas_y2021" ] || [ "$BASENAME" = "vas_y2021" ]; then
        OUTFILE=WEIGHTS/JRA/weights_JRA_${METHOD}.nc
    else
        OUTFILE=WEIGHTS/weights_$BASENAME.nc
    fi

    # Add task
    TASKID=$NTASKS
    NTASKS=$(( NTASKS + 1))
    echo $TASKID ./task.sh "$NAMELIST" "$OUTFILE" >> "$TASKNAME"

    # Create namelist
    cat << EOF > "$NAMELIST"
&grid_inputs
    input_file = './INPUT/$INFILE.nc',
    nemo_file = 'domain_cfg.nc',
    datagrid_file = '$TMPDIR/datagrid_file-$BASENAME.nc',
    nemogrid_file = '$TMPDIR/nemogrid_file-$BASENAME.nc',
    method = 'regular',
    input_lon = '$LON',
    input_lat = '$LAT',
    nemo_lon = 'glamt',
    nemo_lat = 'gphit',
    nemo_mask = 'none',
    nemo_mask_value = 10,
    input_mask = 'none',
    input_mask_value = 10,
/

&remap_inputs
    num_maps = 1,
    grid1_file = '$TMPDIR/datagrid_file-$BASENAME.nc',
    grid2_file = '$TMPDIR/nemogrid_file-$BASENAME.nc',
    interp_file1 = '$TMPDIR/interp_file1-$BASENAME.nc',
    interp_file2 = '$TMPDIR/interp_file2-$BASENAME.nc',
    map1_name = 'input to nemo Mapping',
    map2_name = 'nemo to input Mapping',
    map_method = '$METHOD',
    normalize_opt = 'frac',
    output_opt = 'scrip',
    restrict_type = 'latitude',
    num_srch_bins = 90,
    luse_grid1_area = .false.,
    luse_grid2_area = .false.,
/

&shape_inputs
    interp_file = '$TMPDIR/interp_file1-$BASENAME.nc',
    output_file = '$OUTFILE',
    ew_wrap = 0,
/
EOF
done

# Map CPUS
GAP=$(( 128 / NTASKS ))
MAP=0
for CPU in $(seq $GAP $GAP 128); do
    MAP=$MAP","$CPU
done

# Run tasks
if [ "$USE_MULTI_PROG" = true ]; then
    srun --ntasks="$NTASKS" --mem-bind=local --cpu-bind=v,map_cpu:"$MAP" --multi-prog "$TASKNAME"
else
    while read -r LINE; do
        echo "$LINE"
        eval "${LINE#* }"
    done < "$TASKNAME"
fi

# Bye-Bye
sacct -j "$SLURM_JOB_ID" --units=G --format=JobID,JobName,NNodes,Elapsed,AveRSS,MaxRSS,MaxRSSNode,MaxRSSTask
