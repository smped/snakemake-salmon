rule salmon_quant:
    input:
        config = 'config/config.yml',
        r1 = os.path.join("data", "trimmed", "fastq", "{sample}" + r1 + suffix),
        r2 = os.path.join("data", "trimmed", "fastq", "{sample}" + r2 + suffix),
        index = rules.index_reference.output
    output:
        quant = os.path.join("data", "quants", "{sample}", "quant.sf"),
        aux = temp(
            expand(
                os.path.join(
                    "data", "quants", "{{sample}}", "aux_info", "{file}"
                ),
                file = [
                    'ambig_info.tsv', 'expected_bias.gz', 'exp_gc.gz', 'fld.gz',
                    'meta_info.json', 'observed_bias_3p.gz', 'observed_bias.gz',
                    'obs_gc.gz'
                ]
            )
        ),
        boots = directory(
            os.path.join("data", "quants", "{sample}", "aux_info", "bootstrap")
        ),
        libParams = temp(
            os.path.join(
                "data", "quants", "{sample}", "libParams", "flenDist.txt"
            )
        ),
        logs = temp(
            os.path.join(
                "data", "quants", "{sample}", "logs", "salmon_quant.log"
            )
        ),
        json = temp(
            expand(
                os.path.join("data", "quants", "{{sample}}", "{file}.json"),
                file = ['cmd_info', 'lib_format_counts']
            )
        )
    params:
        dir = os.path.join("data", "quants", "{sample}"),
        lib = config['salmon']['libType'],
        nBoot = config['salmon']['numBootstraps'],
        nGibbs = config['salmon']['numGibbsSamples'],
        thin = config['salmon']['thinningFactor'],
        extra = config['salmon']['extra'],
        git = git_add,
        interval = random.uniform(0, 1),
        tries = 10
    threads: 8
    conda: "../envs/salmon.yml" 
    log: "workflow/logs/salmon/{sample}_quant.log"
    shell:
        """
        salmon quant \
            -i {input.index} \
            -l {params.lib} \
            -p {threads} \
            --numBootstraps {params.nBoot} \
            --numGibbsSamples {params.nGibbs} \
            --thinningFactor {params.thin} \
            {params.extra} \
            -o {params.dir} \
            -1 {input.r1} \
            -2 {input.r2} 

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
            git add {output.quant}
        fi
        """
