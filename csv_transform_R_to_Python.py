import pandas as pd
import numpy as np
import csv

# Rutas de archivos CSV
input_csv = 'RUTA/AL/CSV.csv'
output_csv = 'RUTA/DE/SALIDA/DEL/CSV.csv'

# Mapeo inverso de bandas
inverse_band_map = {
    'B04': 'R', 'B03': 'G', 'B02': 'B',
    'B08': 'NIR', 'B09': 'ndvi', 'B10': 'ndwi'
}

# Leer CSV con manejo de errores y convertidores
df = pd.read_csv(
    input_csv, 
    low_memory=False,
    converters={
        "Index": lambda x: str(x) if pd.notna(x) else None
    }
)

# Convertir 'Index' a datetime y limpiar nulos
df['Index'] = pd.to_datetime(df['Index'], errors='coerce')
df.dropna(subset=['Index'], inplace=True)
df['month'] = df['Index'].dt.month.astype(int)

# Crear diccionario para almacenar filas procesadas
csv_data = {}
for _, row in df.iterrows():
    coord = row['longitude'], row['latitude']
    if coord not in csv_data:
        csv_data[coord] = {'geometry': f'POINT ({row["longitude"]} {row["latitude"]})', 'labelModelo': row['label']}
    
    band_type = inverse_band_map.get(row['band'])
    if band_type:
        column_name = f'{band_type}_{row["month"]}'
        csv_data[coord][column_name] = round(row['value'] * 10000, 6)

# Guardar en CSV
with open(output_csv, 'w', newline='') as outfile:
    fieldnames = ['geometry', 'labelModelo'] + sorted(
        set(k for d in csv_data.values() for k in d.keys() if k not in ('geometry', 'labelModelo'))
    )
    writer = csv.DictWriter(outfile, fieldnames=fieldnames)
    writer.writeheader()
    for record in csv_data.values():
        writer.writerow(record)

print('Reconversión completada exitosamente.')
