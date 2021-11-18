library(tidyverse)
library(glue)

args <- commandArgs(TRUE)
comp <- args[[1]]
rmd <- args[[2]]
comp_split <- str_split(comp, "_")[[1]]
ref <- comp_split[[1]]
treat <- comp_split[[2]]

glue(
	"
	---
	title: '{{treat}} Vs. {{ref}}: Differential Gene Expression'
	date: \"`r format(Sys.Date(), '%d %B, %Y')`\"
	---
	```{r set-knitr-opts, echo=FALSE, child = '../workflow/modules/setup_chunk.Rmd'}
	```
	```{r set-vals}
	treat_levels <- c(\"{{ref}}\", \"{{treat}}\")
	```
	```{r build-from-module, echo = TRUE, child = '../workflow/modules/dge.Rmd'}
	```
	",
	.open = "{{",
	.close = "}}"
) %>%
	write_lines(rmd)