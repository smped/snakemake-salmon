rule fastqc:
    input: 
        config = 'config/config.yml',
        fq = "data/{step}/fastq/{sample}" + suffix
    output:
        html = "data/{step}/FastQC/{sample}_fastqc.html",
        zip = "data/{step}/FastQC/{sample}_fastqc.zip"
    params:
        extra = config['fastqc']['params'],
        git = git_add,
        interval = lambda wildcards: rnd_from_string(
            wildcards.step + wildcards.sample
        ),
        tries = 10
    conda: "../envs/fastqc.yml"
    log: "workflow/logs/FastQC/{step}/{sample}.log"
    threads: 1
    shell:
        """
        # Write to a separate temp directory for each run to avoid I/O clashes
        TEMPDIR=$(mktemp -d -t fqcXXXXXXXXXX)
        fastqc \
          {params.extra} \
          -t {threads} \
          --outdir $TEMPDIR \
          {input.fq} &> {log}
        # Move the files
        mv $TEMPDIR/*html $(dirname {output.html})
        mv $TEMPDIR/*zip $(dirname {output.zip})
        # Clean up the temp directory
        rm -rf $TEMPDIR

        ## Update the git repo if one is active
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

rule find_adapters:
    input:
        r1 = os.path.join(raw_path, "fastq", "{sample}" + r1 + suffix),
        r2 = os.path.join(raw_path, "fastq", "{sample}" + r2 + suffix)
    output: 
        fa = os.path.join(raw_path, "adapters", "{sample}" + '.adapters.fa')
    params:
        git = git_add,
        interval = lambda wildcards: rnd_from_string(wildcards.sample),
        tries = 10
    conda: '../envs/bbmap.yml'
    threads: 4
    log: "workflow/logs/bbmap/find_adapters_{sample}.log"
    shell:
        """
        bbmerge.sh \
            threads={threads} \
            in1={input.r1} \
            in2={input.r2} \
            outa={output.fa} 2> {log}

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

rule remove_adapters:
    input:
        config = 'config/config.yml',
        r1 = os.path.join(raw_path, "fastq", "{sample}" + r1 + suffix),
        r2 = os.path.join(raw_path, "fastq", "{sample}" + r2 + suffix)
    output:
        r1 = temp(
            os.path.join(trim_path, "fastq", "{sample}" + r1 + suffix)
        ),
        r2 = temp(
            os.path.join(trim_path, "fastq", "{sample}" + r2 + suffix)
        ),
        log = os.path.join(trim_path, "logs", "{sample}.settings")
    conda:
        "../envs/adapterremoval.yml"
    params:
        adapter1 = config['trimming']['adapter1'],
        adapter2 = config['trimming']['adapter2'],
        minlength = config['trimming']['minlength'],
        minqual = config['trimming']['minqual'],
        maxns = config['trimming']['maxns'],
        extra = config['trimming']['extra'],
        git = git_add,
        interval = lambda wildcards: rnd_from_string("rmad" + wildcards.sample),
        tries = 10
    threads: 4
    log: "workflow/logs/adapterremoval/{sample}.log"
    shell:
        """
        AdapterRemoval \
            --adapter1 {params.adapter1} \
            --adapter2 {params.adapter2} \
            --file1 {input.r1} \
            --file2 {input.r2} \
            {params.extra} \
            --threads {threads} \
            --maxns {params.maxns} \
            --minquality {params.minqual} \
            --minlength {params.minlength} \
            --output1 {output.r1} \
            --output2 {output.r2} \
            --discarded /dev/null \
            --singleton /dev/null \
            --settings {output.log} &> {log}
            
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
			git add {output.log}
		fi
        """