
#####________________ COMANDO PARA REALIZAR LA IMPLEMENTACIÓN DEL CSV A FORMATO RSTUDIO ________________#####

#Cargar librerias necesarias.
library(dplyr)
library(tibble)
library(purrr)
library(tidyr)
library(sf)
library(sits)

# Cargamos el csv en la ruta correspondiente.
samples <- read.csv("RUTA/AL/CSV.csv")
# Organizamos en el formato/estructura el csv para que RStudio acepte el formato. 
samples_organized <- samples %>%
  pivot_wider(names_from = "band", values_from = "value") %>%  # Volver a formato ancho
  group_by(longitude, latitude, start_date, end_date, label, cube) %>%
  nest(time_series = c(Index, B02, B03, B04, B08, B09, B10))  # Anidar las bandas
samples_organized <- samples_organized %>%
  mutate(time_series = map(time_series, ~ .x %>% mutate(Index = as.Date(Index, format = "%Y-%m-%d"))))
# Posiblemente en la integración de los datos puede llegar a ver en ocasiones errores en el formato de los campos por lo que nso aseguramos de que cada campo tenga su formato.
samples_organized <- samples_organized %>%
  mutate(
    start_date = as.Date(start_date, format = "%Y-%m-%d"),  # Convertir a formato Date
    end_date = as.Date(end_date, format = "%Y-%m-%d"),      # Convertir a formato Date
    label = as.character(label)  # Convertir a character
  )
# Se implementa como un conjunto de datos en formato 'group_dbf' y para aplicar los procesamientos que queremos tenemso que transformarlo a 'sits'.
class(samples_organized) <- c("sits", class(samples_organized))

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

summary(samples)
str(samples)
sits_validate(samples)
sits_labels(samples)
sits_bands(samples)
head(samples)
class(samples)

#####________________ COMANDO PARA REALIZAR HIERARCHICAL CLUSTER (HC) ________________#####

# Realizamos la agrupación que hace HC automáticamente.
samples_HC <- sits_cluster_dendro(
  samples = samples,
  dist_method = "dtw_basic",
  linkage = "ward.D2"
)
# Mostramos la agrupación para observar como se ha clasificado y para eliminar el grupo realizado por el cluster sería el siguiente comando:
samples_HC <- dplyr::filter(samples_HC, cluster != 1) #El valor 1 corresponde con el grupo 1, cambia el valor por el grupo que corresponda.
samples_HC <- sits_cluster_clean(samples_HC)

#####________________ COMANDO PARA REALIZAR SELF-ORGANIZATED MAP (SOM) ________________#####

# Aplicamos la generación de un SOM map.
samples_SOM_cluster <- sits_som_map(samples,
                            grid_xdim = 15,
                            grid_ydim = 15,
                            alpha = 1.0,
                            distance = "dtw",
                            rlen = 20
)
plot(samples_SOM_cluster) #Observamos el SOM map.
som_eval <- sits_som_evaluate_cluster(samples_SOM_cluster) #Lo evaluamos.

# Generamos los samples con el aprendizaje automatico de SOM.
samples_SOM <- sits_som_clean_samples(
  som_map = samples_SOM_cluster,
  prior_threshold = 0.6,
  posterior_threshold = 0.6,
  keep = c("clean", "analyze")
)

#####________________ COMANDO PARA REALIZAR REDUCE SAMPLE IMBALANCE (RSI) ________________#####

# Aplicamos los parámetros correctos de "máximo" y "mínimo" para reducir el samples.
samples_RSI <- sits_reduce_imbalance(
  samples = samples,
  n_samples_over = 1,
  n_samples_under = 100,
  multicores = 4
)

# Durante todo el proceso es recomendable ir observando como se comporta cada conjunto de datos con un "summary()"
