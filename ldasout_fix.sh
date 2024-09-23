#!/bin/bash
#Written by Jing Xiang CHUNG on 23/9/2024
#Prerequisites:
#Please have NCO and CDO installed.
#
#This script fixes various issues plaguing HRLDAS output:
#1. Fix weird "NaNf" in some of the grids.
#2. Fix the attributes of variables, giving them proper missing_value and _FillValue so that the missing values can be read correctly
#3. Fix the lon and lat missing issues.
#4. Fix the missing time issues.

#User's input
#Domain file used to run HRLDAS (to extract lon and lat for HRLDAS output)
domain_file='./geo_em.d01.nc'

#Directory where HRLDAS output is located
indir='hrldas_simulation/LDASOUT'

#Output folder (to store ldasout_fix.sh output)
outdir='LDASOUT_fixed'
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

#Fixing the file
for ifile in `ls ${indir}/??????????.LDASOUT_DOMAIN?`; do

	ofile=`basename ${ifile}`
	ddate=`echo ${ofile} | cut -d "." -f 1`
	
	yy=${ddate:0:4}
	mm=${ddate:4:2}
	dd=${ddate:6:2}
	HH=${ddate:8:2}

	cdo setcalendar,standard -settaxis,${yy}-${mm}-${dd},${HH}:00:00 -setctomiss,-9999 -setctomiss,-1.e+33 -setctomiss,NaNf ${ifile} ${outdir}/${ofile}.tmp1
	ncrename -O -d south_north,lat -d west_east,lon ${outdir}/${ofile}.tmp1 ${outdir}/${ofile}
	
	ncks -A -h -v lat lat.nc3 ${outdir}/${ofile}
	ncks -A -h -v lon lon.nc3 ${outdir}/${ofile}
	
	rm ${outdir}/${ofile}.tmp1
	
done

rm lat.nc3 lon.nc3

echo "Job completed!"
