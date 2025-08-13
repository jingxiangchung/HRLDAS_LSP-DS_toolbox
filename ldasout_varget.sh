#!/bin/bash
#Written by Jing Xiang CHUNG on 23/9/2024
#Prerequisites:
#Please have NCO and CDO installed.
#
#This script extract variables needed and fixes various issues plaguing HRLDAS output:
#1. Fix weird "NaNf" in some of the grids.
#2. Fix the attributes of variables, giving them proper missing_value and _FillValue so that the missing values can be read correctly
#3. Fix the lon and lat missing issues.
#4. Fix the missing time issues.

#User's input
#Domain file used to run HRLDAS (to extract lon and lat for HRLDAS output)
domain_file='./geo_em.d01.nc'

#Directory where HRLDAS output is located
indir='/mnt/h/HRLDAS_GKL_500m/????'

#Output folder (to store ldasout_fix.sh output)
outdir='LDASOUT_extract_500m'

#Variable wanted
var_list='T2 RH2'

#Year start
year_start=2000

#Year end
year_end=2020

#Month start
mon_start=01

#Month end (should the simulation is cross years, put mon_end as 12)
mon_end=12
#---------------------------------------------------------------

[[ ! -d ${outdir} ]] && mkdir -p ${outdir}

dom_file=`basename ${domain_file}`

##1. Get lonlat
#Longitude
cdo mermean -selvar,XLONG_M ${domain_file} lon_${dom_file}.tmp1
        #Reformat the longitude's attributes
        ncrename -O -v XLONG_M,lon lon_${dom_file}.tmp1 lon_${dom_file}.tmp2
        ncdump lon_${dom_file}.tmp2 | sed 's/, x/, lon/g;s/x = /lon = /g;s/Times, y, //g' | ncgen -o lon_${dom_file}.tmp3
        ncks -O -h -C -x -v y,Times lon_${dom_file}.tmp3 lon_${dom_file}.tmp4
        ncatted -O -h -a ,lon,d,, lon_${dom_file}.tmp4 lon_${dom_file}.tmp5
        ncatted -O -h -a standard_name,lon,c,c,"longitude" -a long_name,lon,c,c,"longitude" -a unit,lon,c,c,"degrees_east" -a axis,lon,c,c,"X" lon_${dom_file}.tmp5 lon.nc
                rm lon_${dom_file}.tmp?

#Latitude
cdo zonmean -selvar,XLAT_M ${domain_file} lat_${dom_file}.tmp1
        #Reformat the latitude's attributes
        ncrename -O -v XLAT_M,lat lat_${dom_file}.tmp1 lat_${dom_file}.tmp2
        ncdump lat_${dom_file}.tmp2 | sed 's/, y/, lat/g;s/y = /lat = /g;s/Times, //g;s/, x//g' | ncgen -o lat_${dom_file}.tmp3
        ncks -O -h -C -x -v x,Times lat_${dom_file}.tmp3 lat_${dom_file}.tmp4
        ncatted -O -h -a ,lat,d,, lat_${dom_file}.tmp4 lat_${dom_file}.tmp5
        ncatted -O -h -a standard_name,lat,c,c,"latitude" -a long_name,lat,c,c,"latitude" -a unit,lat,c,c,"degrees_north" -a axis,lat,c,c,"Y" lat_${dom_file}.tmp5 lat.nc
                rm lat_${dom_file}.tmp?

#3. Preparing the lat and lon file
#netCDF4 cannot work in such a way
ncks -O -3 lat.nc lat.nc3; rm lat.nc
ncks -O -3 lon.nc lon.nc3; rm lon.nc

#4. Fixing the file
for var in ${var_list}; do
        for (( y=${year_start}; y<=${year_end}; y++ )); do
                for (( m=${mon_start}; m<=${mon_end}; m++ )); do

                        [[ ${m} -lt 10 ]] && mm=0${m} || mm=${m}

                        ifile_list=`ls ${indir}/${y}${mm}????.LDASOUT_DOMAIN*`
                        for ifile in ${ifile_list}; do
                                ofile=`basename ${ifile}`

                                dataoridate=`echo ${ofile} | cut -d "." -f 1`
                                yyyy=${dataoridate:0:4}
                                mmmm=${dataoridate:4:2}
                                dddd=${dataoridate:6:2}
                                hhhh=${dataoridate:8:2}
                                cdo setcalendar,standard -settaxis,${yyyy}-${mmmm}-${dddd},${hhhh}:00:00,1hour -setctomiss,-9999 -setctomiss,-1.e+33 -setctomiss,NaNf -selvar,${var} ${ifile} ${outdir}/${var}_${ofile}

                        done

                        cdo -O mergetime ${outdir}/${var}_${y}${mm}????.LDASOUT_DOMAIN* ${outdir}/${var}_${y}${mm}.LDASOUT
                                rm ${outdir}/${var}_${y}${mm}????.LDASOUT_DOMAIN*
                done

                cdo -O mergetime ${outdir}/${var}_${y}??.LDASOUT ${outdir}/${var}_${y}.LDASOUT
                        rm ${outdir}/${var}_${y}??.LDASOUT
        done

        cdo -O mergetime ${outdir}/${var}_????.LDASOUT ${outdir}/${var}_${year_start}-${year_end}.LDASOUT.tmp1
        ncrename -O -d south_north,lat -d west_east,lon ${outdir}/${var}_${year_start}-${year_end}.LDASOUT.tmp1 ${outdir}/${var}_${year_start}-${year_end}.LDASOUT
        ncks -A -h -v lat lat.nc3 ${outdir}/${var}_${year_start}-${year_end}.LDASOUT
        ncks -A -h -v lon lon.nc3 ${outdir}/${var}_${year_start}-${year_end}.LDASOUT
                rm ${outdir}/${var}_????.LDASOUT ${outdir}/${var}_${year_start}-${year_end}.LDASOUT.tmp?
done

rm lat.nc3 lon.nc3

echo "Job completed!"
