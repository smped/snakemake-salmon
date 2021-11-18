rule create_site_yml:
    input: 'workflow/scripts/create_site_yml.R'
    output: 'analysis/_site.yml'
    params:
        git = git_add,
        interval = random.uniform(0, 1),
        tries = 10
    threads: 1
    conda: "../envs/diagrammer.yml"
    log: "workflow/logs/create_site_yml.log"
    shell:
        """
        Rscript --vanilla {input} &>> {log}
        if [[ {params.git} == "True" ]]; then
                TRIES={params.tries}
                while [[ -f .git/index.lock ]]
                do
                    if [[ "$TRIES" == 0 ]]; then
                        echo "ERROR: Timeout while waiting for removal of git index.lock" &>> {log}
                        exit 1
                    fi
                    sleep {params.interval}
                    ((TRIES--))
                done
                git add {output}
        fi
        """

rule write_fastqc_summary:
    input:
        config = 'config/config.yml',
        fqc = expand(
                os.path.join("data/{{step}}/FastQC", "{sample}{reads}_fastqc.zip"),
                sample = samples['sample'], reads = [r1, r2],
        ),
        rmd = 'workflow/modules/{step}_fqc.Rmd',
        yaml = os.path.join("analysis", "_site.yml")
    output:
        rmd = 'analysis/{step}_fqc.Rmd',
        html = 'docs/{step}_fqc.html',
        fig_path = directory("docs/{step}_fqc_files/figure-html")
    params:
        git = git_add,
        interval = random.uniform(0, 1),
        tries = 10,
        overwrite = overwrite
    conda: '../envs/ngsReports.yml'
    threads: 1
    log: "workflow/logs/rmarkdown/{step}_fqc.log"
    shell:
        """
        ## Make sure existing files are not overwritten,
        ## unless explicitly requested
        if [[ ! -f {output.rmd} || {params.overwrite} == 'True' ]]; then
            cp {input.rmd} {output.rmd}
        fi

        R -e "rmarkdown::render_site('{output.rmd}')" &>> {log}
        if [[ {params.git} == "True" ]]; then
                TRIES={params.tries}
                while [[ -f .git/index.lock ]]
                do
                    if [[ "$TRIES" == 0 ]]; then
                        echo "ERROR: Timeout while waiting for removal of git index.lock" &>> {log}
                        exit 1
                    fi
                    sleep {params.interval}
                    ((TRIES--))
                done
                git add {output}
        fi
        """

rule write_counts_qc:
    input:
        config = 'config/config.yml',
        quants = expand(
            os.path.join("data", "quants", "{sample}", "quant.sf"),
            sample = samples['sample']
        ),
        rmd = 'workflow/modules/counts_qc.Rmd',
        yaml = os.path.join("analysis", "_site.yml")
    output:
        dge = 'data/quants/dgeNorm.rds',
        logcpm = 'data/quants/logCPM.tsv',
        rmd = 'analysis/counts_qc.Rmd',
        html = 'docs/counts_qc.html',
        fig_path = directory("docs/counts_qc_files/figure-html")
    params:
        git = git_add,
        interval = random.uniform(0, 1),
        tries = 10,
        overwrite = overwrite
    conda: '../envs/counts_qc.yml'
    threads: 1
    log: "workflow/logs/rmarkdown/counts_qc.log"
    shell:
        """
        ## Make sure existing files are not overwritten,
        ## unless explicitly requested
        if [[ ! -f {output.rmd} || {params.overwrite} == 'True' ]]; then
            cp {input.rmd} {output.rmd}
        fi

        R -e "rmarkdown::render_site('{output.rmd}')" &>> {log}
        if [[ {params.git} == "True" ]]; then
                TRIES={params.tries}
                while [[ -f .git/index.lock ]]
                do
                    if [[ "$TRIES" == 0 ]]; then
                        echo "ERROR: Timeout while waiting for removal of git index.lock" &>> {log}
                        exit 1
                    fi
                    sleep {params.interval}
                    ((TRIES--))
                done
                git add {output}
            fi
        """

rule build_site_index:
    input:
        config = 'config/config.yml',
        rmd = os.path.join("workflow", "modules", "index.Rmd"),
        html = ALL_HTML,
        rulegraph = os.path.join("workflow", "rules", "rulegraph.dot"),
        yaml = os.path.join("analysis", "_site.yml")
    output: 
        html = os.path.join("docs", "index.html"),
        rmd = os.path.join("analysis", "index.Rmd")
    params:
        git = git_add,
        interval = random.uniform(0, 1),
        tries = 10,
        overwrite = overwrite
    threads: 1
    conda: "../envs/diagrammer.yml"
    log: "workflow/logs/rmarkdown/build_site.log"
    shell:
        """
        ## Make sure existing files are not overwritten,
        ## unless explicitly requested
        if [[ ! -f {output.rmd} || {params.overwrite} == 'True' ]]; then
            cp {input.rmd} {output.rmd}
        fi

        R -e "rmarkdown::render_site('{output.rmd}')" &>> {log}
        if [[ {params.git} == "True" ]]; then
            TRIES={params.tries}
            while [[ -f .git/index.lock ]]
            do
                if [[ "$TRIES" == 0 ]]; then
                    echo "ERROR: Timeout while waiting for removal of git index.lock" &>> {log}
                    exit 1
                fi
                sleep {params.interval}
                ((TRIES--))
            done
            git add {output}
        fi
        """

