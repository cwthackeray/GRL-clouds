#!/bin/csh

## Script to process CMIP6 data and calculate results shown in Thackeray et al. (2024, GRL) main text.
##
## OVERVIEW:
## - Requires some preprocessing of CMIP6 output.
## - Results are specific to CMIP6 (for brevity, CMIP3/5 data is not included here).
## - Temporary files will be created during processing; they can be removed later with `rm` commands if needed.
## REQUIRED INPUTS:
## - Climatologies from `piControl` runs for several variables (rsds, rsdscs, rsus, rsuscs, tos, clt).
## - Naming convention for climatology files: ${var}_Amon_${model}_piControl_r1_100-130.tm.nc
## - Cloud feedback data from Zelinka et al. (2020), stored in a NetCDF file (`CMIP6.CLDfbk.20GCMs.nc`), with each GCM as a separate timestep.
## DIRECTORY SETUP:
## - dir  : Main directory for CMIP6 data.
## - dir2 : Directory specifically for SST data.
## - work : Working directory for temporary and intermediate files.
## PLOTTING:
## - Figures 1 & 3 were created using Python.
## - Figures 2 & 4 were created using NCL (plotting scripts not included).
##

## Set directories and key file paths
set dir = /work/cwthackeray/models/CMIP6/
set dir2 = /work/cwthackeray/models/CMIP6/sst/
set work = /work/cwthackeray/models/CMIP6/working

## Set cloud feedback file path
set cldfbk_file = "CMIP6.CLDfbk.20GCMs.nc"


######################################
## Figure 1: Surface SWCRE Metrics ##
######################################
# Calculate surface shortwave cloud radiative effect
set models = (ACCESS-CM2 ACCESS-ESM1-5 CanESM5 CESM2 CESM2-WACCM CNRM-CM6-1 CNRM-ESM2-1 EC-Earth3 EC-Earth3-AerChem \
              GFDL-CM4 GFDL-ESM4 GISS-E2-2-G HadGEM3-GC31-LL INM-CM4-8 INM-CM5-0 IPSL-CM6A-LR MIROC6 MPI-ESM1-2-HR \
              MPI-ESM1-2-LR UKESM1-0-LL)
foreach model ($models)

	cdo sub rsds_Amon_${model}_piControl_r1_100-130.tm.nc rsdscs_Amon_${model}_piControl_r1_100-130.tm.nc swcrf_${model}_piControl_r1_100-130.tm.nc
	cdo sub rsus_Amon_${model}_piControl_r1_100-130.tm.nc rsuscs_Amon_${model}_piControl_r1_100-130.tm.nc up-swcrf_${model}_piControl_r1_100-130.tm.nc
	cdo sub swcrf_${model}_piControl_r1_100-130.tm.nc up-swcrf_${model}_piControl_r1_100-130.tm.nc sfc-swcre_${model}_piControl_r1_100-130.tm.nc
	cdo remapbil,r144x90 sfc-swcre_${model}_piControl_r1_100-130.tm.nc sfc-swcre_${model}_piControl_r1_100-130.tm.2D.nc

	# Mean value over 40-50S enlarged to a spatial grid for later calculations
	cdo -L enlarge,r144x90 -fldmean -sellonlatbox,0,360,-50,-40 sfc-swcre_${model}_piControl_r1_100-130.tm.2D.nc sfc-swcre_${model}_piControl_r1_100-130.tm.2D.SH40-50.nc
end
echo "Individual GCM files created"

# Concatenate all models into a single file for ensemble analysis
cdo cat sfc-swcre_*_piControl_r1_100-130.tm.2D.nc CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.nc
cdo cat sfc-swcre_*_piControl_r1_100-130.tm.2D.SH40-50.nc CMIP6.sfc-swcre-40-50S.20GCMs.piControl.100-130.tm.2D.nc

# Create SST mask for gradient metric from ensemble mean
cdo ensmean ${dir2}/tos_Omon_*_piControl_r1_100-130.tm.2D.nc CMIP6mean_tos_piControl_100-130.tm.2D.nc
cdo gec,296.5 CMIP6mean_tos_piControl_100-130.tm.2D.nc CMIP6mean_tos_piControl_100-130.tm.2D.warmmask.nc

# Use SST mask to calculate gradient metric
cdo -L fldmean -ifthen CMIP6mean_tos_piControl_100-130.tm.2D.warmmask.nc CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.nc CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.warmSSTs.nc
cdo -L fldmean -ifnotthen CMIP6mean_tos_piControl_100-130.tm.2D.warmmask.nc CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.nc CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.coolSSTs.nc
cdo -L enlarge,r144x90 -sub CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.warmSSTs.nc CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.coolSSTs.nc CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.warmcoolgradient.nc

# Calculate metrics using cloud feedback file defined above
cdo -L enlarge,r144x90 -zonmean $cldfbk_file CMIP6.CLDfbk.20GCMs.zm.nc   # zonal mean
cdo -L enlarge,r144x90 -fldmean $cldfbk_file CMIP6.CLDfbk.20GCMs.gm.nc   # global mean
cdo -L enlarge,r144x90 -fldmean -sellonlatbox,0,360,-30,30 $cldfbk_file CMIP6.CLDfbk.20GCMs.trop.nc   # tropical mean

# Calculate cross-model correlations
# Since the netcdf files have a different GCM as each timestep we can use the timcor function
cdo timcor CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.warmcoolgradient.nc CMIP6.CLDfbk.20GCMs.zm.nc CMIP6.20GCMs.cmcor.warmcoolgrad_zonalCLDfbk.nc
cdo timcor CMIP6.sfc-swcre-40-50S.20GCMs.piControl.100-130.tm.2D.nc CMIP6.CLDfbk.20GCMs.zm.nc CMIP6.20GCMs.cmcor.40-50S-sfc-swcre_zonalCLDfbk.nc

# We then take the zonal mean of the cross-model correlation to show on the figure
cdo zonmean CMIP6.20GCMs.cmcor.warmcoolgrad_zonalCLDfbk.nc CMIP6.20GCMs.cmcor.warmcoolgrad_zonalCLDfbk.zm.nc
cdo zonmean CMIP6.20GCMs.cmcor.40-50S-sfc-swcre_zonalCLDfbk.nc CMIP6.20GCMs.cmcor.40-50S-sfc-swcre_zonalCLDfbk.zm.nc

# Determine latitudes where zonal mean CF is strongly tied to GCF
cdo -L zonmean -timcor CMIP6.CLDfbk.20GCMs.zm.nc CMIP6.CLDfbk.20GCMs.gm.nc CMIP6.20GCMs.cmcor.globalCLDfbk_zonalCLDfbk.zm.nc
# can use cdo gec,0.7 to isolate mask for areas of strong correlation if needed

# repeat steps for CMIP5 and CMIP3 
# (not shown) 


######################################
## Figure 2: Cross-model correlations ##
######################################
#Local SFC SWCRE vs TCF cross-model correlation maps (panels a-c)
cdo timcor CMIP6.sfc-swcre.20GCMs.piControl.100-130.tm.2D.nc CMIP6.CLDfbk.20GCMs.trop.nc CMIP6.20GCMs.cmcor.sfc-swcre_tropCLDfbk.nc

#Contribution to Cross-model correlation (Following Caldwell et al 2018)
cdo timstd $cldfbk_file CMIP6.CLDfbk.20GCMs.stdev.nc
cdo timstd CMIP6.CLDfbk.20GCMs.gm.nc CMIP6.CLDfbk.20GCMs.gm.stdev.nc
cdo div CMIP6.CLDfbk.20GCMs.stdev.nc CMIP6.CLDfbk.20GCMs.gm.stdev.nc caldwell-var1.nc  # this is shown in Fig S1d
cdo timcor CMIP6.sfc-swcre-40-50S.20GCMs.piControl.100-130.tm.2D.nc $cldfbk_file caldwell-var2.nc
# Multiply contribution terms to obtain final contribution map
cdo mul caldwell-var1.nc caldwell-var2.nc caldwell-contribution-term.nc


######################################
## Figure 3: EC Scatterplots ##
######################################
#Scatterplot of SFC SWCRE and TCF/GCF (panels a,c)
cdo fldmean CMIP6.sfc-swcre-40-50S.20GCMs.piControl.100-130.tm.2D.nc CMIP6.sfc-swcre-40-50S.20GCMs.piControl.100-130.tm.2D.aa.nc 
cdo fldmean CMIP6.CLDfbk.20GCMs.trop.nc CMIP6.CLDfbk.20GCMs.trop.aa.nc
cdo fldmean CMIP6.CLDfbk.20GCMs.gm.nc CMIP6.CLDfbk.20GCMs.gm.aa.nc

## use cdo outputtab to see values or you can send them to a txt file
cdo outputtab,value CMIP6.sfc-swcre-40-50S.20GCMs.piControl.100-130.tm.2D.aa.nc > CMIP6.SFC-SWCRE-40-50S.txt
cdo outputtab,value CMIP6.CLDfbk.20GCMs.trop.aa.nc > CMIP6.TCF.txt
cdo outputtab,value CMIP6.CLDfbk.20GCMs.gm.aa.nc > CMIP6.GCF.txt

# Constrained and unconstrained 95% prediction intervals calculated following Bowman et al. 2018
# We use python for this, but the unconstrained range can also be easily calculated in this script
cdo -L fldmean -timmean CMIP6.CLDfbk.20GCMs.trop.nc CMIP6.CLDfbk.20GCMmean.trop.aa.nc
cdo -L fldmean -timstd CMIP6.CLDfbk.20GCMs.trop.nc CMIP6.CLDfbk.20GCMstdev.trop.aa.nc
cdo mulc,1.96 CMIP6.CLDfbk.20GCMstdev.trop.aa.nc tmp1.nc  # multiply by relevant z-score
cdo add CMIP6.CLDfbk.20GCMmean.trop.aa.nc tmp1.nc tmp.upperbound.nc
cdo sub CMIP6.CLDfbk.20GCMmean.trop.aa.nc tmp1.nc tmp.lowerbound.nc
# The constrained range calculations are more complex (not shown) #


######################################
## Figure 4: Composite groups ##
######################################
# Significance for these maps was calculated within NCL #
#Composite Groups Analysis: move the data for each group into their own directories before this
set group_one_dir = "/work/cwthackeray/models/CMIP6/working/GroupOne"
set group_two_dir = "/work/cwthackeray/models/CMIP6/working/GroupTwo"
set output_dir = "/work/cwthackeray/models/CMIP6/working/"

# Define variables to process ( these variables should be in the filenames, you may need to customize for AMIP sims)
set variables = (CLDfbk clt sfc-swcre tos tos_AMIP)
foreach var ($variables)

    # Prepare file lists for each group
    set group_one_files = (`ls $group_one_dir/*$var*.nc`)
    set group_two_files = (`ls $group_two_dir/*$var*.nc`)

    # Create output filenames
    set output_one = "$output_dir/${var}_group_one_mean.nc"
    set output_two = "$output_dir/${var}_group_two_mean.nc"
    set output_diff = "$output_dir/${var}_group_diff.nc"

    # Compute ensemble means
    cdo ensmean $group_one_files $output_one
    cdo ensmean $group_two_files $output_two
    cdo sub $output_one $output_two $output_diff
end

# Panel f is a simple subtraction
cd /work/cwthackeray/models/CMIP6/working/
cdo sub tos_group_diff.nc tos_AMIP_group_diff.nc panelf.tosdiff.nc

exit
