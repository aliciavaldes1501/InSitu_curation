### Script to get more info about labels ###

# Load libraries

library(here)
library(tidyverse)

# Read data

Nomenclatura_LFiccion <- read_tsv(
  here("data", "raw", "Nomenclatura_LFiccion.txt"), col_names = F) %>%
  select(-X2) %>%
  rename(label = X1, extended_label = X3)

Nomenclatura_LFiccion <- Nomenclatura_LFiccion %>%
  mutate(
    label = str_remove(label, "#\\s*"),
    level1 = str_extract(extended_label, "^\\d+"),
    level2 = str_extract(extended_label, "^\\d+\\.\\d+"),
    level3 = str_extract(extended_label, "^\\d+\\.\\d+\\.\\d+"),
    level4 = str_extract(extended_label, "^\\d+\\.\\d+\\.\\d+\\.\\d+"),
    description = str_remove(extended_label, "^\\d+(\\.\\d+)*\\.*\\s*")
  )

print(Nomenclatura_LFiccion, n = 100)

write.csv(Nomenclatura_LFiccion,
        file = here("data", "clean", "Nomenclatura_LFiccion_AV.csv"))
