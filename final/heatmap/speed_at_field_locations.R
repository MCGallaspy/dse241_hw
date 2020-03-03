library(dplyr)
library(tidyr)
library(ggplot2)
rushes <- read.csv("../rushers_lines.csv", header=TRUE)
nbins <- 100
df <- rushes %>% select(X, Y, S) %>%
  mutate(xbin=ntile(X, 100), ybin=ntile(Y, 53)) %>%
  group_by(xbin, ybin) %>%
  summarise(
    mean_speed = mean(S)
  )
mean_speed <- pivot_wider(df, names_from=xbin, values_from=mean_speed)
ggplot(df, aes(x=xbin, y=ybin, fill=mean_speed)) + geom_tile()