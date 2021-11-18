library(tidyverse)
library(yaml)

# read_yaml("analysis/_site.yml")
config <- here::here("config", "config.yml") %>%
  read_yaml()

## Setup the menu item for each comparison
## Currently, this is only Differential Gene Expression but more can be added
comps <- config$analysis$comparisons %>%
  lapply(
    function(x) {
      list(
        text = paste(x[[2]], "Vs", x[[1]]),
        menu = list(
          list(
            text = "Differential Gene Expression",
            href = paste(x[[1]], x[[2]], "dge.html", sep = "_")
          )
        )
      )
    }
  )

## Now write the yaml to _site.yml
list(
  name = basename(getwd()),
  output_dir = "../docs",
  navbar = list(
    title = basename(getwd()),
    left = c(
      list(
        list(icon = "fa-home", text = "Home", href = "index.html"),
        list(
          text = "QC",
          menu = list(
            list(text = "Raw Data", href = "raw_fqc.html"),
            list(text = "Trimmed Data", href = "trimmed_fqc.html"),
            list(text = "Counts", href = "counts_qc.html")
          )
        )
      ),
      comps
    ),
    right = list(
      list(
        icon = "fa-github",
        href = "https://github.com/steveped/snakemake-salmon"
        )
    )
  ),
  output = list(
    html_document = list(
      toc = TRUE, toc_float = TRUE, code_folding = "hide",
      self_contained = FALSE, theme = "sandstone", highlight = "textmate",
      includes = list(after_body = "footer.html")
    )
  )
) %>%
  write_yaml(
    here::here("analysis/_site.yml")
  )
