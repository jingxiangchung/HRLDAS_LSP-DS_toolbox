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
dir = Path('/mnt/z/HRLDAS_simulations/experiments/2020_GKL_500m_v2/landsat8_2021_GKL')
in_tiff = 'KL_LULC_2021_merged_100_reprojected.tif'
out_tiff = dir / 'KL_LULC_2021_merged_100_regridded.tif'

### Load Data and Clean Clouds/Shadows
da = xr.open_dataset(dir / in_tiff).squeeze()
da = fill_nn(da, mask_value=62)  # Fill clouds
da = fill_nn(da, mask_value=63)  # Fill shadows

### Regrid to 100m Resolution Grid (same with Binary file of CGLC)
new_resolution = 0.000898315284120
min_lon, min_lat, max_lon, max_lat = 101.08, 2.53, 102.12, 3.47

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

