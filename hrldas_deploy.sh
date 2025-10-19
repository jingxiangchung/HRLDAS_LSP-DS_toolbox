#!/bin/bash
#Written by Jing Xiang CHUNG on 23/9/2024
#Preparations for HRLDAS simulation
#This script helps to deploy LSP-DS modded by Ling Bo and Van Doan: https://github.com/xuelingbo/LSP-DS [Accessed on 23/9/2024]
#Instruction: place this script inside the folder you are going to run HRLDAS

#user's input
hrldas_src='/home/jingxiang/climate_models/LSP-DS_mpi'

#File name of geogrid output from WPS's geogrid.exe 
#note: make sure you didn't rename the geogrid output, and the number after "d", should be <10
geo_file='geo_em.d01.nc'

#Folder where you want HRLDAS's LDASIN (input data) and LDASOUT (output files) to be kept
hrldas_out_dir='hrldas_simulation'

#Folder where you want to keep the raw data to create HRLDAS's input data
raw_dir='ERA5_data'

#Starting date of simulation (YYYYMMDD, assuming all simulations will start at 00:00:00)
start_date='20200101'

#Ending date of simulation (YYYYMMDD, assuming all simulations will end at T+1 00:00:00)
#If your simulation is crossing years, suggest start at YYYY-01-01 till YYYY+1-12-31, else when downloading ERA5 and creating forcing, the run_HRLDAS_era5.py will download/create extra files (of course, you can run everything manually to circumvent this problem). 
end_date='20201231'

#Area of simulation (north latitude, west longitude, south latitude, east longitude)
domain_area='3.44, 101.15, 2.75, 101.95'

#---------------------------------------------------------------
#Program start
#0. Calculate how many days of simulations.
echo "[hrldas_deploy] calculating the number of simulation days..."
let kday=($(date +%s -d ${end_date})-$(date +%s -d ${start_date}))/86400
[[ ${kday} < 0 ]] && echo "ERROR: start_date > end_date, did you specified them reversely?" && exit
kday=$((kday+1))

#----------------------------------------------------------------

#1. Obtaining all the needed files
echo "[hrldas_deploy] copying and linking the files needed..."
cp ${hrldas_src}/hrldas/hrldas/run/URBPARM_LCZ.TBL .
cp ${hrldas_src}/hrldas/hrldas/run/NoahmpTable.TBL .
[[ -f hrldas.exe ]] && rm hrldas.exe; ln -s ${hrldas_src}/hrldas/hrldas/run/hrldas.exe .
cp ${hrldas_src}/test/ERA5/namelists/namelist.hrldas .
cp ${hrldas_src}/ERA5_forced/*.py .

#----------------------------------------------------------------

#2. Preparing folders needed
echo "[hrldas_deploy] creating folders needed..."
[[ ! -d ${hrldas_out_dir} ]] && mkdir -p ${hrldas_out_dir}/LDASIN ${hrldas_out_dir}/LDASOUT
[[ ! -d ${raw_dir} ]] && mkdir -p ${raw_dir}

#----------------------------------------------------------------

#3. Preparing HRLDAS's namelist file
echo "[hrldas_deploy] preparing namelist.hrldas file..."

#a. Fixing the HRLDAS setup file name, input and output folder
#note: HRLDAS_setup file naming format: HRLDAS_setup_<simulation_start_date>00_d<last digit of geogrid output file name>
echo "...adding in information on HRLDAS setup file name, input and output folder..."
dnum=`echo ${geo_file} | cut -d "." -f 2 | sed 's/[A-Za-z0]//g'`

sed -i "s:/home/xue/Documents/LSP-DS/test/ERA5/LDASIN/HRLDAS_setup_2020080100_d2:$(pwd)/${hrldas_out_dir}/LDASIN/HRLDAS_setup_${start_date}00_d${dnum}:g;s:/home/xue/Documents/LSP-DS/test/ERA5:$(pwd)/${hrldas_out_dir}:g" namelist.hrldas

#b. Fixing the simulation START_YEAR, START_MONTH, START_DAY and KDAY
echo "...adding in information on simulations start date and days..."
YYYY=${start_date:0:4}; MM=${start_date:4:2}; DD=${start_date:6:2}
sed -i "s:START_YEAR  = 2020:START_YEAR  = ${YYYY}:g;s:START_MONTH = 08:START_MONTH = ${MM}:g;s:START_DAY   = 01:START_DAY   = ${DD}:g;s:KDAY = 31:KDAY = ${kday}:g" namelist.hrldas

#c. Turn on WUDAPT_LCZ
echo "...turning on WUDAPT_LCZ..."
sed -i "s:USE_WUDAPT_LCZ = 0:USE_WUDAPT_LCZ = 1:g" namelist.hrldas

#----------------------------------------------------------------

#4. Preparing run_HRLDAS_era5.py

echo "[hrldas_deploy] preparing run_HRLDAS_era5.py file..."

#a. commenting out unnecessary lines
echo "...commenting out unnecessary lines in run_HRLDAS_era5.py..."
sed -i 's/if not os.path/#if not os.path/g;s/shutil.copy/#shutil.copy/g;s/subprocess./#subprocess./g;s/urbanParamTable =/#urbanParamTable =/g;s/nameList =/#nameList =/g;s/exe_directory =/#exe_directory =/g;s/os.makedirs/#os.makedirs/g;s/os.chdir/#os.chdir/g' run_HRLDAS_era5.py

#b. preparing months list & loop_start and loop_end information
echo "...adding in year, months, loop_start and loop_end information..."
eYYYY=${end_date:0:4}; eMM=${end_date:4:2}; eDD=${end_date:6:2}

if [[ ${eYYYY} -eq ${YYYY} ]]; then
	list=`seq -w ${MM} ${eMM}`
	loop_start=${MM}-${DD}
	loop_end=${eMM}-${eDD}
else
	list=`seq -w 01 12`
	loop_start='01-01'
	loop_end='12-31'
	
fi

mm_list=`echo ${list} | sed "s/ /','/g;s/^/'/g;s/$/'/g"`
sed -i "s/start_year = 2020/start_year = ${YYYY}/g;s/end_year = 2020/end_year = ${eYYYY}/g;s/'08'/${mm_list}/g;s/loop_start_date = '08-01'/loop_start_date = '${loop_start}'/g;s/loop_end_date = '08-31'/loop_end_date = '${loop_end}'/g" run_HRLDAS_era5.py

#c. area
echo "...adding in domain information..."
sed -i "s/55, 30, -50, 155/${domain_area}/g" run_HRLDAS_era5.py

#d. directories
echo "...adding in directories information..."
sed -i "s|= '../test/ERA5/raw/'|= '`pwd`/${raw_dir}/'|g;s|= '../test/ERA5/geo/geo_em.d02.nc'|= '`pwd`/${geo_file}'|g;s|= '../test/ERA5/'|= '`pwd`/${hrldas_out_dir}'|g" run_HRLDAS_era5.py

#e. Changing python to python3 at line 41
echo "...changing python to python3 at line 41 of run_HRLDAS_era5.py..."
sed -i 's/os.system(f"python/os.system(f"python3/g' run_HRLDAS_era5.py

#f. Fix yearly setup file creation issue
echo "...fixing the yearly setup file creation issue..."
sed -i '55,57d' run_HRLDAS_era5.py
echo "$(awk -v n=52 -v s="create_setup_file(f'{str(start_year)}-{loop_start_date}',dir_raw, dir_hrldas,geo_em_file)" 'NR == n {print s} {print}' run_HRLDAS_era5.py)" > run_HRLDAS_era5.py

#----------------------------------------------------------------

#5. Fixing ZR issue in URBPARM_LCZ.TBL

echo "[hrldas_deploy] preparing URBPARM_LCZ.TBL file..."
sed -i 's/ZR: 37.5, 17.5, 6.5, 37.5, 17.5, 6.5, 3., 6.5, 6.5, 10., 10./ZR: 29.5, 17.5, 6.5, 29.5, 17.5, 6.5, 3., 6.5, 6.5, 10., 10./g' URBPARM_LCZ.TBL

#----------------------------------------------------------------

#6. Fixing np.nan in create_forcing.py
sed -i 's/np.NaN/np.nan/g' create_forcing.py

#----------------------------------------------------------------

echo "[hrldas_deploy] Job completed!"
echo "IMPORTANT: Please open and check 'namelist.hrldas' and 'run_HRLDAS_era5.py' carefully!"
echo "           Make appropriate changes if needed before running HRLDAS!"
