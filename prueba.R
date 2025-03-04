library(sitsdata)

# Take only the NDVI and EVI bands
samples_cerrado_mod13q1_2bands <- sits_select(
  data = samples_cerrado_mod13q1,
  bands = c("NDVI", "EVI")
)

# Show the summary of the samples
summary(samples_cerrado_mod13q1_2bands)

# Clustering time series using SOM
som_cluster <- sits_som_map(samples_cerrado_mod13q1_2bands,
                            grid_xdim = 15,
                            grid_ydim = 15,
                            alpha = 1.0,
                            distance = "dtw",
                            rlen = 20
)

# Plot the SOM map
plot(som_cluster)

