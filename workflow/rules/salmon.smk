rule salmon_quant:
    input:
        config = 'config/config.yml',
        r1 = os.path.join(trim_path, "fastq", "{sample}" + r1 + suffix),
        r2 = os.path.join(trim_path, "fastq", "{sample}" + r2 + suffix),
        index = rules.index_reference.output
    output:
        quant = os.path.join(quant_path, "{sample}", "quant.sf"),
        aux = temp(
            expand(
                os.path.join(quant_path, "{{sample}}", "aux_info", "{file}"),
                file = [
                    'ambig_info.tsv', 'expected_bias.gz', 'exp_gc.gz', 'fld.gz',
                    'observed_bias_3p.gz', 'observed_bias.gz', 'obs_gc.gz'
                ]
            )
        ),
        boots = expand(
            os.path.join(
                quant_path, "{{sample}}", "aux_info", "bootstrap", "{file}.gz"
            ),
            file = ['bootstraps', 'names.tsv']
        ),
        libParams = temp(
            os.path.join(quant_path, "{sample}", "libParams", "flenDist.txt")
        ),
        logs = temp(
            os.path.join(quant_path, "{sample}", "logs", "salmon_quant.log")
        ),
        meta = os.path.join(
            quant_path, "{sample}", "aux_info", "meta_info.json"
        ),
        json = expand(
            os.path.join(quant_path, "{{sample}}", "{file}.json"),
            file = ['cmd_info', 'lib_format_counts']
        )
    params:
        dir = os.path.join(quant_path, "{sample}"),
        lib = config['salmon']['libType'],
        nBoot = config['salmon']['numBootstraps'],
        nGibbs = config['salmon']['numGibbsSamples'],
        thin = config['salmon']['thinningFactor'],
        extra = config['salmon']['extra'],
        git = git_add,
        interval = lambda wildcards: rnd_from_string("sq" + wildcards.sample),
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
            -2 {input.r2} &>> {log}

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
            git add {output.quant} {output.json} {output.meta}
        fi
        """
