# HRLDAS_LSP-DS_toolbox
A repo of scripts to make using HRLDAS LSP-DS easier.

Based on WSL2 Ubuntu 24.04.2 LTS 

Scripts:
1. libsetwrf.sh: a script to help in compiling libraries needed to compile WRF and WPS binaries for HRLDAS LSP-DS.

   note:

   i. requires root to install the prerequisites.

   ii. I cannot get Intel OneAPI's compilers to compile Jasper 1.9, thus I am using GNU compilers instead.

2. locate_cmLCZ.sh: a script to identify which CGLC_MODIS_LCZ files to edit based on our simulation domain set.
3. edit_cmLCZ.sh: a script to help preparing the python codes needed to edit CGLC_MODIS_LCZ files based on the LULC tif images obtained from Manila Observatory.
