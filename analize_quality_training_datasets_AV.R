# AV: Code modified based on https://e-sensing.github.io/sitsbook/improving-the-quality-of-training-samples.html

#####________________ COMANDO PARA REALIZAR LA IMPLEMENTACIÓN DEL CSV A FORMATO RSTUDIO ________________#####

# Cargar librerias necesarias.

library(dplyr)
library(tibble)
library(purrr)
library(tidyr)
library(sf)
library(sits)
library(here)

# Cargar objetos grandes guardados

samples_organized <- readRDS(file = here("r_objects", "samples_organized.rds"))
cross_val <- readRDS(file = here("r_objects", "cross_val.rds"))
samples_SOM_cluster <- readRDS(here("r_objects", "samples_SOM_cluster.rds"))
samples_SOM_new_cluster <- readRDS(file = here("r_objects", "samples_SOM_new_cluster.rds"))
samples_RSI <- readRDS(here("r_objects", "samples_RSI.rds"))
som_cluster_bal <- readRDS(file = here("r_objects", "som_cluster_bal.rds"))


# Cargamos el csv en la ruta correspondiente.

samples <- read.csv(here("data", "AT_ALPENNINNE.csv"))

# Organizamos en el formato/estructura el csv para que RStudio acepte el formato. 

samples_organized <- samples %>%
  pivot_wider(names_from = "band", values_from = "value") %>%  # Volver a formato ancho
  group_by(longitude, latitude, start_date, end_date, label, cube) %>%
  nest(time_series = c(Index, B02, B03, B04, B08, B09, B10))  # Anidar las bandas

samples_organized <- samples_organized %>%
  mutate(time_series = map(time_series, ~ .x %>%
                             # Convertir Index a formato Date
                             mutate(Index = as.Date(Index, format = "%Y-%m-%d"))))

# Accedemos a la primera time_series
samples_organized$time_series[[1]]

# Posiblemente en la integración de los datos puede llegar a haber en ocasiones
# errores en el formato de los campos por lo que nos aseguramos de que cada campo tenga su formato.

samples_organized <- samples_organized %>%
  mutate(
    start_date = as.Date(start_date, format = "%Y-%m-%d"),  # Convertir a formato Date
    end_date = as.Date(end_date, format = "%Y-%m-%d"),      # Convertir a formato Date
    label = as.character(label)  # Convertir a character
  )

saveRDS(samples_organized, file = here("r_objects", "samples_organized.rds"))

# We need ungroup() for some algorithms to work

samples_organized_ungr <- samples_organized %>% ungroup()

# Se implementa como un conjunto de datos en formato 'group_dbf' y
# para aplicar los procesamientos que queremos tenemos que transformarlo a 'sits'.

class(samples_organized) <- c("sits", class(samples_organized))
class(samples_organized_ungr) <- c("sits", class(samples_organized_ungr))


#####________________ COMANDO PARA REALIZAR LA OBTENCIÓN DE LOS SAMPLES MEDIANTE RSTUDIO ________________#####
#####________ SIMPLEMENTE AGREGADO PARA CONOCER COMO SE HA OBTENIDO EL ARCHIVO DATA (NO USADO) __________#####

# Cargamos el datacube en el formato que admite SITS.

datacube <- sits_cube(
  source = "MPC",
  collection = "SENTINEL-2-L2A",
  data_dir = "RUTA/AL/DATACUBE"
)

# Cargamos el shapefile de los puntos que solo deben contener la etiqueta 'label'.

shp_file <- "RUTA/AL/SHAPEFILE.shp"
if (file.exists(shp_file)) {
  sf_shape <- st_read(shp_file)
  print(sf_shape)
} else {
  stop("El archivo no existe en la ruta especificada.")
}
# Obtenemos el samples con el que podemos empezar a realizar los analisis.

samples <- sits_get_data(
  cube         = datacube,
  samples      = sf_shape,
  start_date = "2021-01-01",
  end_date = "2021-12-31",
  progress = TRUE
)

#####________________ COMANDO PARA REALIZAR ESTADISTICOS DEL SAMPLES GENERADO ________________#####

# Usamos con samples_organized

summary(samples_organized)
str(samples_organized)

# Cross-validation (uncertainties)
# Default: validation_split = 0.2 (proportion of original time series set to be used for validation)
# Default: Machine learning method (sits_rfor())
# There is also sits_kfold_validate

cross_val <- sits_validate(samples_organized)
cross_val
saveRDS(cross_val, file = here("r_objects", "cross_val.rds"))

# Shows ca. 80% accuracy
# However, this accuracy does not guarantee a good classification result. 
# It only shows if the training data is internally consistent. 
# (https://e-sensing.github.io/sitsbook/improving-the-quality-of-training-samples.html)

sits_labels(samples_organized)
sits_bands(samples_organized)
head(samples_organized)
class(samples_organized)

#####________________ COMANDO PARA REALIZAR HIERARCHICAL CLUSTER (HC) ________________#####

# Realizamos la agrupación que hace HC automáticamente.

samples_HC <- sits_cluster_dendro(samples = samples_organized_ungr,
                                  dist_method = "dtw_basic",
                                  linkage = "ward.D2")

# Error en matrix(0, x_len * (x_len + diagonal_factor)/2L, 1L): 
# valor de 'nrow' no válido (demasiado grande o NA)
# Además: Aviso:
#  In x_len * (x_len + diagonal_factor) : NAs producidos por enteros excedidos

sits_cluster_frequency(samples_HC)

# How to know which cluster to remove? --> The ones with mixes of samples from different labels

# Mostramos la agrupación para observar como se ha clasificado
# y para eliminar el grupo realizado por el cluster sería el siguiente comando:

samples_HC_clean <- dplyr::filter(samples_HC, cluster != 4)
samples_HC_clean <- dplyr::filter(samples_HC, cluster != 5)
samples_HC_clean <- dplyr::filter(samples_HC, cluster != 6)

samples_HC_clean_clean <- sits_cluster_clean(samples_HC_clean)

#####________________ COMANDO PARA REALIZAR SELF-ORGANIZATED MAP (SOM) ________________#####

# Aplicamos la generación de un SOM map.

samples_SOM_cluster <- sits_som_map(samples_organized_ungr,
                                    grid_xdim = 15,
                                    grid_ydim = 15,
                                    alpha = 1.0,
                                    distance = "dtw",
                                    rlen = 20)
# Avisos:
#   1: In sits_som_map(samples_organized_ungr, grid_xdim = 15, grid_ydim = 15,  :
#      recommended values for grid_xdim and grid_ydim are (57 ...62)
#   2: In RcppSupersom(data = data_matrix, codes = init_matrix, numVars = nvar,  :
#      subscript out of bounds (index 1 >= vector size 1)
#   3: In .colors_get(labels = kohonen_obj[["neuron_label"]], legend = NULL,  :
#      missing colors for labels27, 41, 27, 51, 73, 51, 55, 51, 41, 41, 41, 41, 55, 51, 51, 27, 27, 41, 51, 1, 1, 51, 51, 41, 41, 41, 51, 55, 55, 41, 27, 27, 41, 41, 1, 51, 51, 51, 51, 41, 55, 55, 51, 51, 51, 27, 27, 41, 41, 41, 41, 51, 41, 51, 51, 55, 51, 51, 41, 41, 27, 27, 41, 41, 41, 41, 41, 41, 41, 41, 41, 51, 51, 41, 41, 27, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 30, 41, 41, 14, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 30, 41, 40, 41, 41, 41, 41, 27, 41, 41, 41, 41, 41, 41, 41, 27, 27, 41, 41, 41, 41, 27, 27, 27, 27, 41, 41, 41, 41, 41, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 41, 41, 41, 41, 51, 27, 27, 27, 27, 27, 27, 27, 27, 27, 41, 41, 41, 41, 41, 51, 27, 27, 27, 27, 27, 27, 27, 41, 41, 41, 41, 41, 41, 51, 41, 27, 27, 27, 27, 27, 27, 41, 41, 41, 41, 41, 41, 41, 41, 51, 27, 27, 27, 27, 27, 27, 27, 41, 41, 41, 41, 41, 41, 41, 41, 41, 27, 27, 27, 27, 27, 27, 41, 41, 41, 51, 51, 41, 41, 41
#   4: In .colors_get(labels = kohonen_obj[["neuron_label"]], legend = NULL,  : palette for missing colors isSet3

saveRDS(samples_SOM_cluster, file = here("r_objects", "samples_SOM_cluster.rds"))

plot(samples_SOM_cluster, type = "codes") # Observamos el SOM map.

plot(samples_SOM_cluster, band = "B03")
plot(samples_SOM_cluster, band = "B04")
plot(samples_SOM_cluster, band = "B08")
plot(samples_SOM_cluster, band = "B09")
plot(samples_SOM_cluster, band = "B10")

som_eval <- sits_som_evaluate_cluster(samples_SOM_cluster) # Lo evaluamos.
som_eval

# Plot the confusion between clusters
plot(som_eval)

# TO-DO: read about meaning of these results

# Generamos los samples con el aprendizaje automatico de SOM.

samples_SOM <- sits_som_clean_samples(
  som_map = samples_SOM_cluster,
  prior_threshold = 0.6,
  posterior_threshold = 0.6,
  keep = c("clean", "analyze")
)

summary(samples_SOM)
# Quita muchas labels!

samples_SOM %>% count(eval)

# Evaluate the mixture in the SOM clusters of new samples
samples_SOM_new_cluster <- sits_som_map(
  data = samples_SOM,
  grid_xdim = 15,
  grid_ydim = 15,
  alpha = 1.0,
  rlen = 20,
  distance = "dtw"
)

saveRDS(samples_SOM_new_cluster, file = here("r_objects", "samples_SOM_new_cluster.rds"))

plot(samples_SOM_new_cluster, type = "codes")

new_som_eval <- sits_som_evaluate_cluster(samples_SOM_new_cluster)
new_som_eval

# Plot the mixture information.
plot(new_som_eval)

#####________________ COMANDO PARA REALIZAR REDUCE SAMPLE IMBALANCE (RSI) ________________#####

# Aplicamos los parámetros correctos de "máximo" y "mínimo" para reducir el samples.

samples_RSI <- sits_reduce_imbalance(
  samples = samples_organized_ungr,
  n_samples_over = 200, # Changed this value (min count was 214)
  n_samples_under = 2000, # Changed this value
  multicores = 12
)

saveRDS(samples_RSI, file = here("r_objects", "samples_RSI.rds"))

# Print the balanced samples
summary(samples_RSI)

# Clustering time series using SOM
som_cluster_bal <- sits_som_map(
  data = samples_RSI,
  grid_xdim = 15,
  grid_ydim = 15,
  alpha = 1.0,
  distance = "dtw",
  rlen = 20,
  mode = "pbatch" # Not sure why this one, from https://e-sensing.github.io/sitsbook/improving-the-quality-of-training-samples.html
  )

saveRDS(som_cluster_bal, file = here("r_objects", "som_cluster_bal.rds"))

# Produce a tibble with a summary of the mixed labels
som_eval_RSI <- sits_som_evaluate_cluster(som_cluster_bal)
som_eval_RSI

# Show the result
plot(som_eval_RSI)

# Durante todo el proceso es recomendable ir observando como se comporta cada conjunto de datos con un "summary()"

