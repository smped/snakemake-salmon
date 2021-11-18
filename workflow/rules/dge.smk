rule make_dge_template:
    input:
        rmd = 'workflow/modules/dge.Rmd',
        script = 'workflow/scripts/create_dge.R',
        setup = 'workflow/modules/setup_chunk.Rmd'
    output:
        rmd = 'analysis/{comp}_dge.Rmd'
    params:
        comp = "{comp}",
        git = git_add,
        interval = random.uniform(0, 1),
        tries = 10,
        overwrite = overwrite
    conda: '../envs/dge.yml'
    threads: 1
    log: "workflow/logs/rmarkdown/make_{comp}_dge_template.log"
    shell:
        """
        ## Make sure existing files are not overwritten,
        ## unless explicitly requested
        if [[ ! -f {output.rmd} || {params.overwrite} == 'True' ]]; then
            Rscript --vanilla \
                {input.script} \
                {params.comp} \
                {output.rmd} &>>{log}
        fi
        
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

rule run_dge_analysis:
    input:
        dge = 'data/quants/dgeNorm.rds',
        logcpm = 'data/quants/logCPM.tsv',
        rmd = 'analysis/{comp}_dge.Rmd',
        yaml = os.path.join("analysis", "_site.yml")
    output:
        html = 'docs/{comp}_dge.html',
        fig_path = directory("docs/{comp}_dge_files/figure-html")
    params:
        git = git_add,
        interval = random.uniform(0, 1),
        tries = 10,
        overwrite = overwrite
    conda: '../envs/dge.yml'
    threads: 1
    log: "workflow/logs/rmarkdown/{comp}_dge.log"
    shell:
        """
        R -e "rmarkdown::render_site('{input.rmd}')" &>> {log}
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