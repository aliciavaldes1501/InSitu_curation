import csv
import re
import time
import pandas as pd
from tqdm import tqdm  # Asegúrate de tener instalada la librería tqdm: pip install tqdm

# Rutas de archivos CSV
input_csv = 'C:/Data/PAs/AT_ATLIBERIA.csv'
output_csv = 'C:/Data/PAs/AT_ATLIBERIA_R.csv'


# Mapeo de bandas
band_map = {
    'R': 'B04', 'G': 'B03', 'B': 'B02',
    'NIR': 'B08', 'ndvi': 'B09', 'ndwi': 'B10'
}

# Fechas para cada mes
date_map = {i: f'2021-{i:02d}-01' for i in range(1, 13)}

# Iniciar contador de tiempo
start_time = time.time()

# Leer y convertir CSV
data = []
with open(input_csv, 'r') as infile:
    reader = list(csv.DictReader(infile))
    for row in tqdm(reader, desc="Procesando filas"):
        match = re.search(r'\(([-\d\.]+)\s+([-\d\.]+)\)', row['geometry'])
        if not match:
            continue
        longitude, latitude = map(float, match.groups())
        label = row['labelModelo']
        start_date, end_date, cube = '2021-01-01', '2021-12-01', 'SENTINEL-2-L2A'

        for key, value in row.items():
            band_match = re.match(r'(\w+)_([1-9]|1[0-2])$', key)
            if band_match:
                band_type, month = band_match.groups()
                index_date = date_map[int(month)]
                band = band_map.get(band_type)
                if band:
                    value = float(value)
                    # Dividir por 10000 para las bandas específicas
                    if band in ['B02', 'B03', 'B04', 'B08']:
                        value /= 10000
                    data.append([longitude, latitude, start_date, end_date, label, cube, index_date, band, value])

# Crear DataFrame y formatear columnas
df = pd.DataFrame(data, columns=[
    'longitude', 'latitude', 'start_date', 'end_date',
    'label', 'cube', 'Index', 'band', 'value'
])

# Formateo de datos
df["longitude"] = df["longitude"].astype(float)
df["latitude"] = df["latitude"].astype(float)
df["start_date"] = pd.to_datetime(df["start_date"]).dt.date
df["end_date"] = pd.to_datetime(df["end_date"]).dt.date
df["Index"] = pd.to_datetime(df["Index"]).dt.date
df["band"] = df["band"].astype(str)
df["value"] = df["value"].astype(float)

# Guardar CSV
df.to_csv(output_csv, index=False)

# Mostrar tiempo total de ejecución
end_time = time.time()
print(f"Conversión completada exitosamente en {end_time - start_time:.2f} segundos.")
