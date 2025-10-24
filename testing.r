library(ggplot2)
library(dplyr)
library(plotly)
bills = read.csv("data/testdata.csv")


data = bills %>% count(status)


# Basic piechart
ggplot(data, aes(x="", y=n, fill=status)) +
  geom_bar(stat="identity", width=1, color = "white") +
  coord_polar("y", start=0) +
  geom_text(aes(label = n), color = "white", position = position_stack(vjust = 0.5)) +
  scale_fill_manual(labels = c("Failed", "In Progress", "Passed"), values = c("#BE2A3E", "#EACF65", "#3C8D53")) +
  ggtitle("Bill Status Distribution") +
  theme_void() +
  theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom", legend.title = element_blank())


plot_ly(data, labels = ~status, values = ~n, type = 'pie') %>% layout(title = "")


df <- bills_map
grouped_df <- df %>% group_by(state)
summarized_df <- dplyr::summarise(grouped_df,
   popup = paste(
      paste0(statute_number, " (", year, ") - ", status),
      collapse = "<br>"),
    rep_status = case_when(
            any(status == "passed") ~ "passed",
            any(status == "in progress") ~ "in progress",
            TRUE ~ "failed")
  )

        
        
        ,
        rep_status = case_when(
            any(status == "passed") ~ "passed",
            any(status == "in progress") ~ "in progress",
            TRUE ~ "failed"
        ), .groups = "drop")
      
    return(df_summary)