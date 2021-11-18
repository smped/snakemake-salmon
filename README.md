# snakemake-salmon

A simple Snakemake workflow for processing RNA-Seq using snakemake in conjunction with `salmon`.
Data is **assumed to be paired-end**, and a two-treatment design is assumed, although multiple paired comparisons are also possible
The steps implemented are:

1. Prepare the reference
	- Download the `fa` and `gtf` files for the relevent build
	- Prepare the set of decoy transcripts
	- Index the reference using the set of decoy transcripts
2. Pre-process raw fq files
	- Run QC and prepare a report on the raw fq files (`FastQC`/`ngsReports`)
	- Identify adapters (`bbtools`)
	- Trim samples (`AdapterRemoval`)
3. Pre-process raw fq files trimmed samples
	- Run QC and prepare a report on the raw fq files (`FastQC`/`ngsReports`)
4. Align and quantify (`salmon quant`)
5. Gene Level Differential Expression Analysis 
	- Normalise using `cqn`
	- Compare groups using quasi-likelihood approaches and `glmTreat`
	- Perform an alternative analysis using `limma-voom`

## Required Setup

Prior to executing the workflow, please ensure the following steps have been performed

1. Place unprocessed `fastq` (or `fastq.gz`) files in `data/raw/fastq`. This path is hard-wired into the workflow and cannot be changed. If samples have been run across multiple lanes, please merge prior to running this workflow as all samples are expected to be in a single pair of files.
2. Prepare a tab-separated file, usually `samples.tsv` and place this in the `config` directory. The column name `sample` is mandatory, however any other columns required in the analysis can be specified in `config.yml`
3. Edit `config.yml` as required. Fields cannot be changed

## Snakemake implementation

The basic workflow is written `snakemake` and can be called using the following steps.

Firstly, setup the required conda environments

```
snakemake \
	--use-conda \
	--conda-prefix '/home/steveped/mambaforge/envs/' \
	--conda-create-envs-only \
	--cores 1
```

Secondly, create and inspect the rulegraph

```
snakemake --rulegraph > workflow/rules/rulegraph.dot
dot -Tpdf workflow/rules/rulegraph.dot > workflow/rules/rulegraph.pdf
```

Finally, the workflow itself can be run using:

```
snakemake \
	-p \
	--use-conda \
	--conda-prefix '/home/steveped/mambaforge/envs/' \
	--notemp \
	--keep-going \
	--cores 16
```

- All data (salmon quants, trimmed fastq etc) will be written to the `data` directory. Trimmed fastq and `salmon quant aux_info` files are makred as temporary and can be saefly deleted after copletion of the analysis
- RMarkdown files will be added to the `anaylsis` directory using modules provided in the workflow
- Compiled `html` files will be written to the `docs` folder, along with any topTable files

Note that this creates common environments able to be called by other workflows and is dependent on the user.
For me, my global conda environments are stored in `/home/steveped/mambaforge/envs/`.
For other users, this path will need to be modified.