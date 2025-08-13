#!/bin/bash
#Written by Jing Xiang CHUNG on 6/8/2025
#Convert HRLDAS output to netcdf4-zip

#HRLDAS output files directory
indir='/mnt/f/HRLDAS_simulations/experiments/2020_GKL_500m/hrldas_simulation/LDASOUT'

#Starting year to compress
year_start=2011

#Ending year to compress
year_end=2015

#------------------------------------------------

for (( y=${year_start}; y<=${year_end}; y++ )); do

        [[ ! -d ${y} ]] && mkdir -p ${y}

        for m in {01..12}; do

                ifile_list=`ls ${indir}/${y}${m}????.LDASOUT_DOMAIN1`

                for ifile in ${ifile_list}; do
                        ofile=`basename ${ifile}`

                        echo "Compressing file ${ofile}..."
                        nccopy -d5 ${ifile} ${y}/${ofile}.nc4z
                done

        done

done

echo "Job completed!"
