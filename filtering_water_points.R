ggplot(samples_organized_ungr %>% filter(label == 73) %>% unnest(),
       aes(x = B09)) +
  geom_histogram(color = "black", fill = "white")

samples_organized_ungr %>% filter(label == 73)

(samples_organized_ungr %>% filter(label == 73))$time_series[[1]]
(samples_organized_ungr %>% filter(label == 73))$time_series[[2]]
(samples_organized_ungr %>% filter(label == 73))$time_series[[3]]

filtered_ALPENNINNE <- samples_organized_ungr %>%
  filter(label == 73) %>%
  unnest(time_series) %>%
  group_by(longitude, latitude, start_date, end_date, label, cube) %>%
  mutate(sum_B09 = sum(B09)) %>%
  filter(sum_B09 < 0.1) %>% # Sum of the time series < 0.1 - USE THIS
  nest(time_series = c(Index, B02, B03, B04, B08, B09, B10))

write.csv(filtered_ALPENNINNE,
          file = here("data", "clean", "filtered_ALPENNINNE.csv"))
