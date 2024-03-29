# RAPID-Evolution

Global configurations at eORCA025 and eORCA12 with a high resolution nest covering the RAPID array and neighbouring latitudes in the North Atlantic.


## Quick start on {Archer2|Anemone}
```shell
git clone git@github.com:NOC-MSM/RAPID-Evolution.git 
cd RAPID-Evolution
./setup {-s Archer2}
```
The setup script downloads nemo, compiles tools and configurations. Setup defaults to Anemone, which is ideally suited for fast development/turnaround of smaller configurations (e.g. eORCA025). 

### For Development 

The global eORCA025 and nested eORCA025-RAPID12 configurations are ready to run. All that is required is:

```shell
cd nemo/cfgs/GLOBAL_QCO/eORCA025

qsub run_nemo1326_24x_v2.slurm
```

```shell
cd nemo/cfgs/AGRIF_QCO/eORCA025-RAPID12

qsub run_nemo1326_24x_v2.slurm
```

```shell
cd nemo/cfgs/AGRIF_QCO/eORCA025-RAPID12-RAPID36

qsub run_nemo1326_24x_v2.slurm
```

There are a few variables to set in the runscript. For example, the following variables will generate a 2-hour simulation split in 1-hour jobs.
```bash
# ========================================================
# PARAMETERS TO SET
# Restart frequency (<0 days, >0 hours)
FREQRST=1
# Simulation length (<0 days, >0 hours)
LENGTH=2
# Parent initial time step (0: infer from time.step)
# PARENT_IT000 != 0 -> auto-resubmission is switched OFF
PARENT_IT000=0
# Name of this script (to resubmit)
SCRIPTNAME=run_nemo.slurm
# =======================================================
```

We will start by implementing a 1/12° nest in eORCA025. This will enable faster testing and development, and provide a template for reproducing the domain at higher resolution.


### Submitting on Archer2 

Simulations of eORCA12 with or without nests are best done on Archer2. 

Change directory to the NEMO experiment directory:
```shell
cd nemo/cfgs/GLOBAL_QCO/eORCA12
```
and create a runscript:

Example `mkslurm_NPD` settings for eORCA12 production runs on Archer2:
```shell
../../../scripts/python/mkslurm_NPD -S 48 -s 16 -m 1 -C 5504 -g 0 -a n01-CLASS -j eORCA12 -t 1-00:00:00 --gnu > run_nemo5504_48X.slurm

../../../scripts/python/mkslurm_NPD -S 48 -s 16 -m 1 -C 8238 -g 0 -a n01-CLASS -j eORCA12 -t 0-00:10:00 --gnu > run_nemo8238_48X.slurm

../../../scripts/python/mkslurm_NPD -S 48 -s 16 -m 1 -C 11168 -g 0 -a n01-CLASS -j eORCA12 -t 0-00:10:00 --gnu > run_nemo11168_48X.slurm
```

Finally:
```shell
sbatch run_nemo[...].slurm
```


## Configurations:

### Global eORCA025
Resolution:
- Horizontal: 1/4°
- Vertical: 75 levels

### Global eORCA025-RAPID12 (in progress)
Resolution:
- Horizontal: 1/4°
- Vertical: 75 levels
- 1/12° AGRIF nest extending over 6°N-42°N

### Global eORCA025-RAPID12-RAPID36 (in progress)
Resolution:
- Horizontal: 1/4°
- Vertical: 75 levels
- 1/12° AGRIF nest extending over 6°N-42°N
- 1/36° AGRIF nest extending over 19°N-31°N


### Global eORCA12
Resolution:
- Horizontal: 1/12°
- Vertical: 75 levels

### Global eORCA12-RAPID36 (planned)
Resolution:
- Horizontal: 1/12°
- Vertical: 75 levels
- 1/36° AGRIF nest extending over 19°N-31°N

### Global eORCA12-RAPID36-GSRIDGE36 (planned)
Resolution:
- Horizontal: 1/12°
- Vertical: 75 levels
- 1/36° AGRIF nest extending over 19°N-31°N
- 1/36° AGRIF nest over the Greenland-Scotland Ridge (see IMMERSE WP6.2)


## Administrative notes:

The RAPID-Evolution repo is forked from NOC_Near_Present_Day, with the NPD repo added as upstream:

```
git remote add upstream git@github.com:NOC-MSM/NOC_Near_Present_Day.git
```

This means that RAPID-Evolution can be synced with progress on NOC_Near_Present_Day. See:

https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork
