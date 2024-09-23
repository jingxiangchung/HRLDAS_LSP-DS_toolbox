# HRLDAS-LSP-DS Toolbox
This repo hosts some scripts written to aid in the application of HRLDAS LSP-DS

Scripts available:
1. extract_geo_em.sh, script to extract information from geo_em file generated from WRF Pre-Processing System (WPS) geogrid.exe so that it can be read on GrADS. Usage: bash extract_geo_em.sh <geo_em file> <variable wanted>, e.g. : bash extract_geo_em.sh geo_em.d01.nc LU_INDEX
2. hrldas_deploy.sh, script to set up the HRLDAS LSP-DS (https://github.com/xuelingbo/LSP-DS, accessed 23/9/2024).
3. ldasout_fix.sh, script to fix HRLDAS LSP-DS output files so that they can be read correctly by Climate Data Operators and GrADS
  [Note: currently the ldasout_fix.sh behaves slowly, will update it later]
