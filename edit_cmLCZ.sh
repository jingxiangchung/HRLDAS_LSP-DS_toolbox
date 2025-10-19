#!/bin/bash
#Written by Jing Xiang CHUNG on 16/7/2025
#Edit the CGLC_MODIS_LCZ_global files with LULC wanted
#Prerequisite: 
#1. Please run "locate_cmlcz.sh" first to bring over the files to be edited.

##User's input
#Domain leftmost longitude
dlon_L=101.08

#Domain rightmost longitude
dlon_R=102.12

#Domain bottom-most latitude
dlat_B=2.53

#Domain top-most latitude
dlat_T=3.47

#Directory storing the original CGLC_MODIS_LCZ_global files
cmlcz_ori_dir='/mnt/z/HRLDAS_simulations/WPS_GEOG/CGLC_MODIS_LCZ_global'

#Directory containing CGLC_MODIS_LCZ_global files copied by "locate_cmlcz.sh"
cmlcz_src_dir='./CGLC_MODIS_LCZ_global_mod'

#Folder containing LULC tif files and which tif file to use
tif_dir='./landsat8_2021_GKL'
tif_file='KL_LULC_2021_merged_100.tif'

#Where you want to store the edited CGLC_MODIS_LCZ_global files?
odir='data-CGLC-2021'

#-----------------------
##Installing needed modules
#pip install rioxarray cartopy geocube

#-----------------------
#For generating Jenn's Python codes (let's avoid modifying her original codes at this stage)

function write_py_code {

cat << EOF > 01_tiff_reproject_template.py 
"""
Reproject LANDSAT7 (from GED) 
to EPSG:4326

Created on 13 May 2025
"""
#----------------------------------------------------------------------------- 
#%%
from pathlib import Path
import rasterio
from rasterio.warp import calculate_default_transform, reproject, Resampling
#%%
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
def reproject_tiff(input_path, output_path, dst_crs='EPSG:4326'):
    """
    Reprojects a TIFF file to a specified coordinate reference system.

    Args:
        input_path (str): Path to the input TIFF file.
        output_path (str): Path to save the reprojected TIFF file.
        dst_crs (str, optional): Destination CRS in EPSG format. Defaults to 'EPSG:4326'.
    """
    with rasterio.open(input_path) as src:
        transform, width, height = calculate_default_transform(
            src.crs, dst_crs, src.width, src.height, *src.bounds)
        
        kwargs = src.meta.copy()
        kwargs.update({
            'crs': dst_crs,
            'transform': transform,
            'width': width,
            'height': height
        })

        with rasterio.open(output_path, 'w', **kwargs) as dst:
            for i in range(1, src.count + 1):
                reproject(
                    source=rasterio.band(src, i),
                    destination=rasterio.band(dst, i),
                    src_transform=src.transform,
                    src_crs=src.crs,
                    dst_transform=transform,
                    dst_crs=dst_crs,
                    resampling=Resampling.nearest)
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
dir = Path('/home/jtibay/WRF_v4/modified_cglc_100m/landsat7/')

in_tiff = dir / 'MM_LULC2002_128clean.tif'
out_tiff = dir / 'MM_LULC2002_128clean_reproject.tif'

### Reproject and Save to GeoTIFF
reproject_tiff(in_tiff, out_tiff)

print(f"GeoTIFF saved at {out_tiff}")

EOF

cat << EOF > 02_tiff_regrid100_template.py 
"""
Convert LANDSAT7 (from GED) 
to 100m same as binary of CGLC

Created on 13 May 2025
------
Note: 
    1. Need to make the resolution the same as binary (cs=0.000898315284120)
       of CGLC-MODIS-LCZ (100m)
"""
#----------------------------------------------------------------------------- 
#%%
from pathlib import Path
from geocube.api.core import make_geocube
import geopandas as gpd
import pandas as pd
import xarray as xr
import numpy as np
import rasterio
from rasterio.transform import from_origin
from scipy.interpolate import NearestNDInterpolator
from scipy.spatial import cKDTree
#%%
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
def fill_nn(da, mask_value):
    mask = da.band_data == mask_value
    valid_mask = ~mask & ~np.isnan(da.band_data)
    valid_rows, valid_cols = np.where(valid_mask)
    kdtree = cKDTree(np.column_stack((valid_rows, valid_cols)))
    valid_values = da.band_data.values[valid_mask]
    for row, col in zip(*np.where(mask)):
        idx = kdtree.query([[row, col]], k=1)[1][0]
        da.band_data.values[row, col] = valid_values[idx]
    return da
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
### Define Paths
dir = Path('/home/jtibay/WRF_v4/modified_cglc_100m/landsat7/')
in_tiff = 'MM_LULC2002_128clean_reproject.tif'
out_tiff = 'TIFF/landsat_20012002_100m.tif'

### Load Data and Clean Clouds/Shadows
da = xr.open_dataset(dir / in_tiff).squeeze()
da = fill_nn(da, mask_value=62)  # Fill clouds
da = fill_nn(da, mask_value=63)  # Fill shadows

### Regrid to 100m Resolution Grid (same with Binary file of CGLC)
new_resolution = 0.000898315284120
min_lon, min_lat, max_lon, max_lat = 120.5, 14.0, 121.65, 15.0

new_x = np.arange(min_lon, max_lon, new_resolution)
new_y = np.arange(max_lat, min_lat, -new_resolution)  # Descending y for top-down

regridded_da = da.interp(x=new_x, y=new_y, method='nearest')
regridded_array = regridded_da.band_data.values.astype(np.float32)

### Save to GeoTIFF
transform = from_origin(min_lon, max_lat, new_resolution, new_resolution)

meta = {
    'driver': 'GTiff',
    'count': 1,
    'dtype': 'float32',
    'crs': 'EPSG:4326',  # WGS 84
    'transform': transform,
    'width': len(new_x),
    'height': len(new_y),
}

with rasterio.open(out_tiff, 'w', **meta) as dst:
    dst.write(regridded_array, 1)

print(f"GeoTIFF saved at {out_tiff}")

EOF

cat << EOF > 03_LULCupdate_2001_template.py
"""
Updating the LULC over Metro Manila (MM) using NAMRIA data 

Created by Gewell Llorin 
Contact at gewell.llorin@gmail.com
Updated on 22 March 2023
------
Edited by jtlopez on 10 July 2024
Notes: 
    1. This edit is for updating CGLC_MODIS_LCZ_global (100m) for 
       two binary files covering MM extended domain (120.3, 122.3, 9, 18.9)
    2. Info from index of CGLC_MODIS_LCZ_global (100m)
        type=categorical
        category_min=1
        category_max=61
        projection=regular_ll
        dx=0.000898315284120
        dy=0.000898315284120
        known_x=1
        known_y=1
        known_lat=-59.999376141627145
        known_lon=-179.99992505544913
        wordsize=1
        tile_x=1089
        tile_y=10973 
        tile_z=1
        missing_value=0
        endian=little
        filename_digits=6
        mminlu="MODIFIED_IGBP_MODIS_NOAH"
        units="category"
        description="natural CGLC mapped to MODIS and built LCZ categories"
    3. To get which binary files to update for MM:
        extended MM coords: 120.6, 121.6, 14, 15
        xstart-xend.ystart-yend
        xstart = (120.6 - known_lon) / dx
        ystart = (14 - known_lat) / dy
        xend = ((121.6 - 120.6) / dx) + xstart
        yend = ((15 - 14) / dy) + ystart
        xstart-xend.ystart-yend = 334626-335740.082375-083489
        the binary files that has extended MM are:
        1. 334324-335412.076812-087784
        2. 335413-336501.076812-087784
    4. Only one tif file (not whole PH, just covering the area of two binaries)
"""
#---------------------------------------------------------------------------------
#%%
### Import the needed libraries 
import os
import pdb
import matplotlib.pyplot as plt
import re
import numpy as np
import xarray as xr
from pathlib import Path
import rioxarray
from cartopy import crs as ccrs
from scipy.interpolate import NearestNDInterpolator
#%%

#---------------------------------------------------------------------------------
### Define paths, files
mainFolder = Path('/prod/projects/data/thanhnx/202408-CARE/HRLDAS/v20240920/LSP-DS/202506_new-LULC-data/')
binaryFilePath = mainFolder / 'data-CGLC-orig/' #path to your binary files
landsatFilePath = mainFolder / 'data-conv/' #path to your update TIFF files
savePath = mainFolder / 'data-CGLC-2001/' # path to where you'll be saving the modified binary files
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
### Function to load a binary file into a dataarray
def loadBF(binaryFile, dtype=np.int8, cs=0.000898315284120, tile_x=1089, tile_y=10973, border=None, thirdD=None):
  '''
  :param binaryFile: path to the binary file to be opened
  :param dtype: the data type of each entry in the binary file (consult wordsize argument in index file and User Guide for this)
  :param cs: conversion factor of binary file resolution to degrees 
  :param grids: number of grids along one edge of the binary file tile (find this under tile_x/y entry of index file)
  :param border: number of halo grids along the edges of the binary file (find this under tile_bdr entry of index file, if none leave as None)
  :param thirdD: if binary file is 3D, place here the number of grids in the 3rd dimension (find this under tile_z entry of index file, if none leave as None)
  :return da: a 2D/3D dataarray of the binary file with (thirdD) x lat x lon dimensions 
  '''
  
  if thirdD is None: 
    a = np.fromfile(binaryFile, dtype=dtype).reshape(tile_y, tile_x)  # Reading the binary file as an np array, then reshaping to a 2D tile
  else:
    a = np.fromfile(binaryFile, dtype=dtype).reshape(thirdD, tile_y, tile_x)  # for 3D binary files

  # Reading the grid limits from the name of the old land use file, then converting to degrees
  x1, x2, y1, y2 = map(int, re.split('\.|-', binaryFile.name))
  if border is not None: # account for border grids 
    x1 -= border
    x2 += border
    y1 -= border
    y2 += border
  Y = np.linspace(y1 * cs, y2 * cs, tile_y, endpoint=True) - 59.999376141627145
  X = np.linspace(x1 * cs, x2 * cs, tile_x, endpoint=True) - 179.99992505544913

  # Making a DataArray from the old land use, assigning coordinates 
  if len(a.shape) == 2:
    return xr.DataArray(a, coords=[Y, X], dims=['lat', 'lon'])
  elif len(a.shape) == 3:
    return xr.DataArray(a, coords=[range(1, thirdD + 1), Y, X], dims=['thirdD', 'lat', 'lon'])
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
### Function for updating a binary file with updated land cover data from a preprocessed TIFF file
def update(oldLU, newLU, dtype=np.int8, cs=0.000898315284120, tile_x=1089, tile_y=10973, save=True, toraster=True, savepath=None, **kwargs):
    '''
    :param oldLU: Path to default binary file
    :param newLU: Path to TIFF file containing updated data. Note! It must follow the resolution of the binary file 
    :param dtype: data type to read binary file contents as 
    :param cs: arcsecond to degree conversion ratio
    :param grids: number of grids on one side of binary file tile
    :param save: If the resulting land use file is to be saved. Default name is f'{oldLU}Updated'
    :param: toraster: If the resulting land use file is to be saved as a TIFF for visualization. Default name is f'{oldLU}Updated.tif'
    :param: savepath: where to save output files. Default is in the same folder as the original ones 
    :return:
    da - DataArray containing the updated landuse file
    oldda - DataArray containing the old land use data read from oldLU
    update - DataArray containing data from the tif file read from newLU e.g. what to update the old land use with
    '''

    # open binary file as a dataarray
    print('Opening default binary file')
    da = loadBF(oldLU, dtype=dtype, cs=cs, tile_x=tile_x, tile_y=tile_y, **kwargs)

    # Reading the new land use file
    print('Opening update TIFF file')
    update = newLU 
    update = update.sortby('y')

    # Getting the lowerleft coordinate of the new land use file, to know which part of the map will be updated
    print('Getting coordinates')
    x0 = (update.x[0] - cs / 2) / cs   # convert to grid coordinates
    y0 = (update.y[0] - cs / 2) / cs

    # Reassigning coordinates of the new land use file to match the old file's grid, since it might be off by a bit
    print('Reassigning coordinates')
    #update = update.drop('band').squeeze()

    # TNX: Thank for Nguyen-Ngoc-Minh Tam suggestion
    x0 = x0.values # <- newly added
    y0 = y0.values # <- newly added 

    update = update.assign_coords({'x': np.linspace(x0 * cs, (x0 + len(update.x)) * cs, len(update.x), endpoint=False)})
    update = update.assign_coords({'y': np.linspace(y0 * cs, (y0 + len(update.y)) * cs, len(update.y), endpoint=False)})
    

    # Saving the old land use file for reference
    oldda = da.copy()

    # Getting intersection between coordinates
    print('Locating bounds')
    y1 = max(update.y[0], da.lat[0])  # x1, y1 the LL coordinate; you want it to be the larger coordinate
    x1 = max(update.x[0], da.lon[0])
    y2 = min(update.y[-1], da.lat[-1])  # x2, y2 the UR coordinate; you want it to tbe the smaller
    x2 = min(update.x[-1], da.lon[-1])

    # Overwriting the old land use with the new land use (+- cs/2 to include the slice in case of a slight difference in the values)
    print('Updating')
    da.loc[slice(y1 - cs / 2, y2 + cs / 2), slice(x1 - cs / 2, x2 + cs / 2)] = \
        update.loc[slice(y1 - cs / 2, y2 + cs / 2), slice(x1 - cs / 2, x2 + cs / 2)].values
      
    if save:
        print('Saving updated binary file')
        if savepath is None:   
            da.values.flatten().tofile(f'{oldLU}Updated')
        else:
            da.values.flatten().tofile(savepath / oldLU.name)

    if toraster:
        print('Saving updated TIFF file')
        oldda.rename({'lat': "y", 'lon': "x"}).assign_coords({"y": da.lat.values + cs / 2, "x": da.lon.values + cs / 2}) \
            .rio.to_raster(f'{oldLU}Default.tif')
        if savepath is None:
            da.rename({'lat': "y", 'lon': "x"}).assign_coords({"y": da.lat.values + cs / 2, "x": da.lon.values + cs / 2})\
                .rio.to_raster(f'{oldLU}Updated.tif')
        else:
            da.rename({'lat': "y", 'lon': "x"}).assign_coords({"y": da.lat.values + cs / 2, "x": da.lon.values + cs / 2}) \
                .rio.to_raster(savepath / f'{oldLU.name}Updated.tif')

    return da, oldda, update
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
### Function to convert values inside a dataarray 
def convert(da, oldVals, newVals):
  '''
  :param da: the dataarray to be modified 
  :param oldVals: a list of the original values in the dataarray to be replaced
  :param newVals: the list of new values to replace the old values, following the order of the oldVals list
  :param nanVal: if there are null values in the dataarray, what to convert them to?
  :return newDA: the modified dataarray 
  '''
  
  refDA = da.copy()
  newDA = da.copy()

  for oldVal, newVal in zip(oldVals, newVals):
    newDA = newDA.where(refDA != oldVal, newVal)
  

  return newDA
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
### Open LANDSAT7 TIFF files 
# Note: No need to convert, landsat7 has been processed to follow CGLC categories 

#updateDA = xr.open_dataset(landsatFilePath / 'landsat_20012002_100m.tif')
updateDA = xr.open_dataset(landsatFilePath / 'HAN_LULC_100m_reproject_fnl.tif')
updateDA = updateDA.band_data
updateDA = updateDA.squeeze()
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
### Update the binary files per quadrant covering the Philippines 
for file in binaryFilePath.glob('*-*-*'):
  print(file.name)
  update(binaryFilePath / file, updateDA, savepath=savePath)

EOF

}

#-----------------------
#Generating Jenn's Python codes template if not available.
[[ ! -f 01_tiff_reproject_template.py || ! -f 02_tiff_regrid100_template.py || ! -f 03_LULCupdate_2001_template.py ]] && echo "Generating necessary Python codes..." && write_py_code

#Let's start modifying the codes to suits our needs.
#01_tiff_reproject_template.py
sed "s|dir = Path('/home/jtibay/WRF_v4/modified_cglc_100m/landsat7/')|dir = Path('${tif_dir}')|g" < 01_tiff_reproject_template.py > 01_tiff_reproject_updated.py
outtif=`echo ${tif_file} | rev | cut -d "." -f 2- | rev`
sed -i "s|MM_LULC2002_128clean.tif|${tif_file}|g" 01_tiff_reproject_updated.py
sed -i "s|MM_LULC2002_128clean_reproject.tif|${outtif}_reproject.tif|g" 01_tiff_reproject_updated.py

#02_tiff_regrid100_template.py
sed "s|dir = Path('/home/jtibay/WRF_v4/modified_cglc_100m/landsat7/')|dir = Path('${tif_dir}')|g" < 02_tiff_regrid100_template.py > 02_tiff_regrid100_updated.py
sed -i "s,MM_LULC2002_128clean_reproject.tif,${outtif}_reproject.tif,g" 02_tiff_regrid100_updated.py
sed -i "s,TIFF/landsat_20012002_100m.tif,${tif_dir}/${outtif}_reproject_regrid.tif,g" 02_tiff_regrid100_updated.py
sed -i "s|min_lon, min_lat, max_lon, max_lat = 120.5, 14.0, 121.65, 15.0|min_lon, min_lat, max_lon, max_lat = ${dlon_L}, ${dlat_B}, ${dlon_R}, ${dlat_T}|g" 02_tiff_regrid100_updated.py

#03_LULCupdate_2001_template.py
sed "s|binaryFilePath = mainFolder / 'data-CGLC-orig/'|binaryFilePath = Path('${cmlcz_src_dir}')|g" < 03_LULCupdate_2001_template.py > 03_LULCupdate_2001_updated.py
sed -i "s|landsatFilePath = mainFolder / 'data-conv/'|landsatFilePath = Path('${tif_dir}')|g" 03_LULCupdate_2001_updated.py
sed -i "s|savePath = mainFolder / 'data-CGLC-2001/'|savePath = Path('${odir}')|g" 03_LULCupdate_2001_updated.py
sed -i "s|updateDA = xr.open_dataset(landsatFilePath / 'HAN_LULC_100m_reproject_fnl.tif')|updateDA = xr.open_dataset(landsatFilePath / '${outtif}_reproject_regrid.tif')|g" 03_LULCupdate_2001_updated.py
sed -i "s|update(binaryFilePath / file, updateDA, savepath=savePath)|update(file, updateDA, savepath=savePath)|g" 03_LULCupdate_2001_updated.py

rm -rf 01_tiff_reproject_template.py 02_tiff_regrid100_template.py 03_LULCupdate_2001_template.py

#-----------------------
#Running the necessary Python codes and link the edited CGLC-MODIS-LCZ files back to its original path

[[ ! -d ${odir} ]] && mkdir -p ${odir}
[[ ! -f ${cmlcz_src_dir}/??????-??????.??????-??????Default.tif ]] && rm -rf ${cmlcz_src_dir}/??????-??????.??????-??????Default.tif

python 01_tiff_reproject_updated.py 
python 02_tiff_regrid100_updated.py 
python 03_LULCupdate_2001_updated.py

cmLCZ_edited_list=`ls ${odir}/??????-??????.??????-??????Updated.tif | sed 's/Updated.tif//g'`
odir_fullpath=`realpath ${odir}`

for cfile in ${cmLCZ_edited_list}; do

	bin_file=`basename ${cfile}`
	[[ ! -f ${cmlcz_ori_dir}/${bin_file}.bak ]] && echo "Creating backup for file ${bin_file}..." && mv ${cmlcz_ori_dir}/${bin_file} ${cmlcz_ori_dir}/${bin_file}.bak
	echo "Linking file ${odir_fullpath}/${bin_file} to ${cmlcz_ori_dir}..."
	ln -s ${odir_fullpath}/${bin_file} ${cmlcz_ori_dir}

done

echo "Job completed!"
