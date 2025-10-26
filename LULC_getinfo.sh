#!/bin/bash
#Extract LULC information from geo_em's LU_INDEX
#Prerequisite: please extract LU_INDEX from geo_em using extract_geo_em.sh

lulc_file_list='2000/LU_INDEX_geo_em.d01.nc 2020/LU_INDEX_geo_em.d01.nc'
label_for_lulc='Landsat7 CGLC_MODIS_LCZ'
lulc_code_info='cmLCZ_LULC_code.dat'

#----------------------------------------
lulc_lab=(${label_for_lulc})

count=0
for f in ${lulc_file_list}; do

	echo "Working on ${f}: for ${lulc_lab[${count}]}..."
	linnum=`ncdump -v LU_INDEX ${f} | grep -n "LU_INDEX =" | cut -d ":" -f 1`
	lulc=`ncdump -v LU_INDEX ${f} | tail -n +$((linnum+1)) | sed 's/[^0-9,]//g' | sed 's/,/\n/g' | sed '/^$/d'`
	lulc_tcount=`echo "${lulc}" | wc -l`

	echo "Landuse_Code,Landuse_Name,Num_Pixel,Total_Pixel,%area" > ${lulc_lab[${count}]}_LULC_info.csv

	lulc_uniq=`echo "${lulc}" | sort -n | uniq`
	for ltype in ${lulc_uniq}; do

		#Obtain lulc name from $lulc_code_info
		lulc_name=`cat ${lulc_code_info} | grep "^${ltype}. " | cut -d "." -f 2-`

		printf "...working on LULC type ${ltype}:${lulc_name}..."
		lulc_count=`echo "${lulc}" | grep -w ${ltype} | wc -l`
		lulc_cperc=`echo ${lulc_count} ${lulc_tcount} 100 | awk -F " " '{printf "%.4f\n",$1/$2*$3}'`
		printf "${lulc_cperc}%%...\n"
		echo "${ltype},${lulc_name},${lulc_count},${lulc_tcount},${lulc_cperc}" >> ${lulc_lab[${count}]}_LULC_info.csv
	done
#exit
	count=$((count+1))
done

echo "Job completed!"

