#!/bin/bash
#Written by Jing Xiang CHUNG on 16/7/2025
#Locate CGLC_MODIS_LCZ_global files to be edited

##User's input
#Domain leftmost longitude
dlon_L=101.0859

#Domain rightmost longitude
dlon_R=102.1141

#Domain bottom-most latitude
dlat_B=2.538345

#Domain top-most latitude
dlat_T=3.461433

#Directory storing the original CGLC_MODIS_LCZ_global files
cmlcz_dir='/mnt/f/HRLDAS_simulations/WPS_GEOG/CGLC_MODIS_LCZ_global'

#Where to keep the copied files for editing?
odir='./CGLC_MODIS_LCZ_global_mod'

xinc=1089
yinc=10973

#------------------------------------------------------------------
##Program start, DO NOT change anything after here unless you know what you are doing...

[[ ! -f ${cmlcz_dir}/index ]] && echo 'ERROR: File named "index" for CGLC_MODIS_LCZ_global is missing, please re-download the CGLC_MODIS_LCZ_global data!' && exit

#*******
#Calculate index of the binary file should be modified
known_lon=`cat ${cmlcz_dir}/index | grep known_lon | cut -d "=" -f 2`
known_lat=`cat ${cmlcz_dir}/index | grep known_lat | cut -d "=" -f 2`
dx=`cat ${cmlcz_dir}/index | grep dx | cut -d "=" -f 2`
dy=`cat ${cmlcz_dir}/index | grep dy | cut -d "=" -f 2`

x0=`echo ${dlon_L} ${known_lon} ${dx} | awk '{print ($1-$2)/$3}'`
y0=`echo ${dlat_B} ${known_lat} ${dy} | awk '{print ($1-$2)/$3}'`

x1=`echo ${dlon_R} ${known_lon} ${dx} | awk '{print ($1-$2)/$3}'`
y1=`echo ${dlat_T} ${known_lat} ${dy} | awk '{print ($1-$2)/$3}'`

xstart=`echo ${x0} | cut -d "." -f 1`; xstart_d=`printf "%06d\n" ${xstart}`
ystart=`echo ${y0} | cut -d "." -f 1`; ystart_d=`printf "%06d\n" ${ystart}`

xend=$(( `echo ${x1} | cut -d "." -f 1`+1 )); xend_d=`printf "%06d\n" ${xend}`
yend=$(( `echo ${y1} | cut -d "." -f 1`+1 )); yend_d=`printf "%06d\n" ${yend}`

#*******
#Identify the files we should modified
echo "Searching for files covering ${xstart_d}-${xend_d}.${ystart_d}-${yend_d} ... please wait ..."
cmlcz_files=`ls ${cmlcz_dir}/??????-??????.??????-?????? | rev | cut -d "/" -f 1 | rev`

#Files for xstart
#xstart must always >= file lon ID (file lon ID - xstart = -ive)
xstart_file_idx=`echo "${cmlcz_files}" | cut -d "-" -f 1 | sed 's/^0\+//g' | awk '{print $1-'${xstart}'}'`
xstart_src=`echo "${xstart_file_idx}" | grep -w "0"`
[[ ${xstart_src} == "" ]] && xstart_src=`echo "${xstart_file_idx}" | grep - | sed 's/-//g' | sort -n | head -n 1`
xstart_file_pos=`echo "${xstart_file_idx}" | grep -nw "0\|-${xstart_src}" | cut -d ":" -f 1`
xstart_file_pos=`echo ${xstart_file_pos} | sed 's/ /p /g;s/$/p/g;s/ / -e /g;s/^/-e /g'`
xstart_files=`echo "${cmlcz_files}" | sed -n ${xstart_file_pos}`

#Files for xend
#xend must always <= file lon ID (file lon ID -xend = +ive)
#Does our xstart files encompasses our xend?
xstart_files_endID=`echo "${xstart_files}" | cut -d "-" -f 2 | cut -d "." -f 1 |  uniq | sed 's/^0\+//g'` #xstart_files_endID should only have 1 value, if there are multiple values, something is wrong.

if [[ ${xend} -le ${xstart_files_endID} ]]; then

	xend_files="${xstart_files}"

else

	xstart_files_startID=`echo "${xstart_files}" | cut -d "-" -f 1 | uniq | sed 's/^0\+//g'` #xstart_files_startID should only have 1 value, if there are multiple values, something is wrong.
	xend_files_startID=$((xstart_files_startID+xinc))

	while [[ ${xend} -ge ${xend_files_startID} ]]; do
		xend_files_startLIST=(${xend_files_startLIST[@]} ${xend_files_startID})
		xend_files_startID=$((xend_files_startID+xinc))
	done

	xend_files=`ls $(printf "%06d\n" ${xend_files_startLIST[@]} | sed "s, , ${cmlcz_dir}/,g;s,^,${cmlcz_dir}/,g" | sed 's/ /-* /g;s/$/-*/g') | rev | cut -d '/' -f 1 | rev`

fi

x_files=`printf "${xstart_files}\n${xend_files}\n" | sort -n | uniq`

#Files for ystart
#We already obtain the possible files having our xstart and xend, let's start from there.
#ystart must always >= file lat ID (file lat ID - ystart = -ive)
ystart_file_idx=`echo "${x_files}" | cut -d "." -f 2 | cut -d "-" -f 1 | sed 's/^0\+//g' | awk '{print $1-'${ystart}'}'`
ystart_src=`echo "${ystart_file_idx}" | awk '$1 <= 0' |  sed 's/-//g' | sort -n | head -n 1`
ystart_file_pos=`echo "${ystart_file_idx}" | grep -nw "0\|-${ystart_src}" | cut -d ":" -f 1`
ystart_file_pos=`echo ${ystart_file_pos} | sed 's/ /p /g;s/$/p/g;s/ / -e /g;s,^,-e ,g'`
ystart_files=`echo "${x_files}" | sed -n ${ystart_file_pos}`

#Files for yend
#yend must always <= file lat ID (file lat ID -yend = +ive)
#Does our ystart files encompasses our yend?
ystart_files_endID=`echo "${ystart_files}" | cut -d "." -f 2 | cut -d "-" -f 2 |  uniq | sed 's/^0\+//g'` #ystart_files_endID should only have 1 value, if there are multiple values, something is wrong.

if [[ ${yend} -le ${ystart_files_endID} ]]; then

        yend_files="${ystart_files}"

else

        ystart_files_startID=`echo "${ystart_files}" | cut -d "." -f 2 | cut -d "-" -f 1 | uniq | sed 's/^0\+//g'` #ystart_files_startID should only have 1 value, if there are multiple values, something is wrong.
        yend_files_startID=$((ystart_files_startID+yinc))

        while [[ ${yend} -ge ${yend_files_startID} ]]; do
                yend_files_startLIST=(${yend_files_startLIST[@]} ${yend_files_startID})
                yend_files_startID=$((yend_files_startID+yinc))
        done

	yend_src=`printf "%06d\n" ${yend_files_startLIST[@]} | sed 's/^/-e ./g'`
	yend_files=`echo "${x_files}" | grep ${yend_src}`

fi

y_files=`printf "${ystart_files}\n${yend_files}\n" | sort -n | uniq`

#*******
echo "... file(s) identified:"
echo "${y_files}"

[[ ! -d ${odir} ]] && mkdir -p ${odir}
xy_files=`echo ${y_files} | sed "s, , ${cmlcz_dir}/,g;s,^,${cmlcz_dir}/,g"`

echo "...copying files to ${odir}..."
cp ${xy_files} ${odir}/

echo "Job completed!"

