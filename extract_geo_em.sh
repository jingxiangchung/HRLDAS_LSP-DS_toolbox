#!/bin/bash
#Written by Jing Xiang CHUNG on 23/9/2024
#Prerequisites: install CDO and NCO
#Usage: bash extract_geo_em.sh <geo_em file> <variable wanted>
#E.g. : bash extract_geo_em.sh geo_em.d01.nc LU_INDEX
#
#Note: you can check what variable available by using ncdump -h

ifile=${1}
geo_var=${2}

#----------------------------------------------
#Start program

[[ ${ifile} == "" ]] && echo "Please provide geo_em file wanted!" && exit
[[ ${geo_var} == "" ]] && echo "Please provide geo_em file's variable wanted!" && exit 

chkvar=`cdo showname ${ifile} | grep ${geo_var}`
[[ ${chkvar} == "" ]] && echo "ERROR: Variable specified: ${geo_var}, not available!" && exit

[[ -f ${geo_var}_${ifile} ]] && rm ${geo_var}_${ifile}
#1. Extract data wanted
cdo setcalendar,standard -selvar,${geo_var} ${ifile} ${geo_var}_${ifile}.tmp1
	ncrename -O -d south_north,lat ${geo_var}_${ifile}.tmp1 ${geo_var}_${ifile}.tmp2
	ncrename -O -d west_east,lon ${geo_var}_${ifile}.tmp2 ${geo_var}_${ifile}.tmp3
	
	rm ${geo_var}_${ifile}.tmp1 ${geo_var}_${ifile}.tmp2

#2. Correct the given attribute from lon and lat
#Longitude
cdo mermean -selvar,XLONG_M ${ifile} ${geo_var}_lon_${ifile}.tmp1
	#Reformat the longitude's attributes
	ncrename -O -v XLONG_M,lon ${geo_var}_lon_${ifile}.tmp1 ${geo_var}_lon_${ifile}.tmp2
	ncdump ${geo_var}_lon_${ifile}.tmp2 | sed 's/, x/, lon/g;s/x = /lon = /g;s/Times, y, //g' | ncgen -o ${geo_var}_lon_${ifile}.tmp3
	ncks -O -h -C -x -v y,Times ${geo_var}_lon_${ifile}.tmp3 ${geo_var}_lon_${ifile}.tmp4
	ncatted -O -h -a ,lon,d,, ${geo_var}_lon_${ifile}.tmp4 ${geo_var}_lon_${ifile}.tmp5
	ncatted -O -h -a standard_name,lon,c,c,"longitude" -a long_name,lon,c,c,"longitude" -a unit,lon,c,c,"degrees_east" -a axis,lon,c,c,"X" ${geo_var}_lon_${ifile}.tmp5 lon.nc
		rm ${geo_var}_lon_${ifile}.tmp?

#Latitude
cdo zonmean -selvar,XLAT_M ${ifile} ${geo_var}_lat_${ifile}.tmp1
	#Reformat the latitude's attributes
	ncrename -O -v XLAT_M,lat ${geo_var}_lat_${ifile}.tmp1 ${geo_var}_lat_${ifile}.tmp2
	ncdump ${geo_var}_lat_${ifile}.tmp2 | sed 's/, y/, lat/g;s/y = /lat = /g;s/Times, //g;s/, x//g' | ncgen -o ${geo_var}_lat_${ifile}.tmp3
	ncks -O -h -C -x -v x,Times ${geo_var}_lat_${ifile}.tmp3 ${geo_var}_lat_${ifile}.tmp4
	ncatted -O -h -a ,lat,d,, ${geo_var}_lat_${ifile}.tmp4 ${geo_var}_lat_${ifile}.tmp5
	ncatted -O -h -a standard_name,lat,c,c,"latitude" -a long_name,lat,c,c,"latitude" -a unit,lat,c,c,"degrees_north" -a axis,lat,c,c,"Y" ${geo_var}_lat_${ifile}.tmp5 lat.nc
		rm ${geo_var}_lat_${ifile}.tmp?

#3. Append the correct lon and lat to ${geo_var}
#netCDF4 cannot work in such a way
ncks -O -3 ${geo_var}_${ifile}.tmp3 ${geo_var}_${ifile}; rm ${geo_var}_${ifile}.tmp3
ncks -O -3 lat.nc lat.nc3; rm lat.nc
ncks -O -3 lon.nc lon.nc3; rm lon.nc

ncks -A -h -v lat lat.nc3 ${geo_var}_${ifile}
ncks -A -h -v lon lon.nc3 ${geo_var}_${ifile}
	rm l??.nc3

echo "Job completed!"

