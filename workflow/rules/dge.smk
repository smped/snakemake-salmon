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
        interval = rnd_from_string("make_dge_template"),
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
        data = expand(
            os.path.join(quant_path, "{file}"), 
            file = ['dgeNorm.rds', 'logCPM.tsv']
        ),
        rmd = 'analysis/{comp}_dge.Rmd',
        yaml = os.path.join("analysis", "_site.yml")
    output:
        files = expand(
            os.path.join("docs", "{{comp}}_{file}"),
            file = ['dge.html', 'topTable.tsv']
        ),
        fig_path = directory("docs/{comp}_dge_files/figure-html")
    params:
        git = git_add,
        interval = rnd_from_string("run_dge_analysis"),
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