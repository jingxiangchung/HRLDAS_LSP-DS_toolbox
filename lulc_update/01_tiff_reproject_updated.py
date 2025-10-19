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
dir = Path('/mnt/z/HRLDAS_simulations/experiments/2020_GKL_500m_v2/landsat8_2021_GKL')

in_tiff = dir / 'KL_LULC_2021_merged_100.tif'
out_tiff = dir / 'KL_LULC_2021_merged_100_reprojected.tif'

### Reproject and Save to GeoTIFF
reproject_tiff(in_tiff, out_tiff)

print(f"GeoTIFF saved at {out_tiff}")


