![image](https://github.com/user-attachments/assets/3c9d0498-0e2f-42df-9f92-de16cb6319be)# HRLDAS-LSP-DS Toolbox
This repo hosts some scripts written to aid in the application of HRLDAS LSP-DS

Scripts available:
1. extract_geo_em.sh, script to extract information from geo_em file generated from WRF Pre-Processing System (WPS) geogrid.exe so that it can be read on GrADS. Usage: bash extract_geo_em.sh <geo_em file> <variable wanted>, e.g. : bash extract_geo_em.sh geo_em.d01.nc LU_INDEX
2. hrldas_deploy.sh, script to set up the HRLDAS LSP-DS (https://github.com/xuelingbo/LSP-DS, accessed 23/9/2024). Might need to run "pip3 install basemap setuptools pandas xarray eccodes netCDF4 h5netcdf scipy rioxarray cfgrib" after that, before we can run the model.
3. ldasout_fix.sh, script to fix HRLDAS LSP-DS output files so that they can be read correctly by Climate Data Operators and GrADS.
   [Note: ldasout_fix.sh behaves very slowly because it is trying to correct everything. Thus, using this script is not recommended and will not be updated in future]
4. ldasout_varget.sh, script to extract variables wanted from HRLDAS LSP-DS output files and fix them so that they can be read correctly by Climate Data Operators and GrADS.
