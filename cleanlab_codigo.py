import pandas as pd
import numpy as np
from cleanlab.classification import CleanLearning
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

def main():
    # Ruta del archivo CSV de entrada
    input_csv = r'RUTA/AL/CSV.csv'

    # Cargar los datos del CSV
    df = pd.read_csv(input_csv)

    # Especificar las columnas de características (bandas) y la clase objetivo
    X_columns = [
        'R_1', 'G_1', 'B_1', 'NIR_1', 'ndvi_1', 'ndwi_1',
        'R_2', 'G_2', 'B_2', 'NIR_2', 'ndvi_2', 'ndwi_2',
        'R_3', 'G_3', 'B_3', 'NIR_3', 'ndvi_3', 'ndwi_3',
        'R_4', 'G_4', 'B_4', 'NIR_4', 'ndvi_4', 'ndwi_4',
        'R_5', 'G_5', 'B_5', 'NIR_5', 'ndvi_5', 'ndwi_5',
        'R_6', 'G_6', 'B_6', 'NIR_6', 'ndvi_6', 'ndwi_6',
        'R_7', 'G_7', 'B_7', 'NIR_7', 'ndvi_7', 'ndwi_7',
        'R_8', 'G_8', 'B_8', 'NIR_8', 'ndvi_8', 'ndwi_8',
        'R_9', 'G_9', 'B_9', 'NIR_9', 'ndvi_9', 'ndwi_9',
        'R_10', 'G_10', 'B_10', 'NIR_10', 'ndvi_10', 'ndwi_10',
        'R_11', 'G_11', 'B_11', 'NIR_11', 'ndvi_11', 'ndwi_11',
        'R_12', 'G_12', 'B_12', 'NIR_12', 'ndvi_12', 'ndwi_12'
    ]
    y_column = 'labelModelo'

    # Extraer las características (X) y la variable objetivo (y)
    X = df[X_columns]
    y = df[y_column]

    # Convertir las etiquetas de clase a valores consecutivos usando LabelEncoder
    le = LabelEncoder()
    y_encoded = le.fit_transform(y)

    # Dividir los datos en conjuntos de entrenamiento y prueba
    X_train, X_test, y_train, y_test = train_test_split(
        X, y_encoded, test_size=0.2, random_state=42
    )

    # Usar un clasificador RandomForest
    clf = RandomForestClassifier(random_state=42)
    clf.fit(X_train, y_train)

    # ------------------------- FIX: Ajustar pred_probs ------------------------- #
    # Generar predicciones probabilísticas para todo el conjunto de datos (X)
    pred_probs = clf.predict_proba(X)

    # Corregir la matriz de predicciones para que tenga columnas de todas las clases
    total_classes = len(np.unique(y_encoded))
    full_pred_probs = np.zeros((X.shape[0], total_classes))
    full_pred_probs[:, clf.classes_] = pred_probs

    # ------------------------- CleanLearning para detectar errores ------------------------- #
    cleaner = CleanLearning(clf, seed=42)

    # Detectar problemas de clasificación en las etiquetas
    label_issues = cleaner.find_label_issues(
        labels=y_encoded, pred_probs=full_pred_probs
    )

    # Filtrar los índices de los problemas de etiquetado
    is_label_issue_mask = label_issues['is_label_issue']

    # Filtrar las filas que no tienen problemas de etiquetado
    df_cleaned = df[~is_label_issue_mask]

    # También eliminar filas con baja calidad de etiqueta (<0.85)
    low_quality_mask = label_issues['label_quality'] < 0.85
    df_cleaned = df_cleaned[~low_quality_mask]

    # Calcular el número de puntos eliminados
    num_removed = df.shape[0] - df_cleaned.shape[0]
    print(f"Número de puntos eliminados: {num_removed}")

    # Guardar el CSV limpio
    output_csv = r'RUTA/AL/CSV/SALIDA.csv'
    df_cleaned.to_csv(output_csv, index=False)

    print(f"El archivo filtrado ha sido guardado en: {output_csv}")


if __name__ == '__main__':
    main()
