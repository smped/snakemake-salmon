# Example:
# ftp://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
ref_url = urllib.parse.urlunparse(
	(
		'ftp', 'ftp.ensembl.org',
		'pub/release-' + ref_release + '/fasta/' + ref_species +'/dna/' +
		species_upr + '.' + ref_build + '.dna.primary_assembly.fa.gz',
		'', '', ''
	)
)


# Example
# http://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/cdna/Homo_sapiens.GRCh38.cdna.all.fa.gz
trans_url = urllib.parse.urlunparse(
	(
		'ftp', 'ftp.ensembl.org',
		'pub/release-' + ref_release + '/fasta/'+ ref_species + '/cdna/' +
		species_upr + '.' + ref_build + '.cdna.all.fa.gz',
		'', '', ''
	)
)

# Example:
# ftp://ftp.ensembl.org/pub/release-104/gtf/homo_sapiens/Homo_sapiens.GRCh38.104.gtf.gz
gtf_url = urllib.parse.urlunparse(
	(
		'ftp', 'ftp.ensembl.org',
		'pub/release-' + ref_release + '/gtf/'+ ref_species + '/' +
		species_upr + '.' + ref_build + '.' + ref_release + '.gtf.gz',
		'', '', ''
	)
)


rule download_genome:
	input: 'config/config.yml'
	output: os.path.join(ref_path, ref_fa)
	params:
		url = ref_url
	log: "workflow/logs/reference/download_genome.log"
	threads: 1
	conda: "../envs/samtools.yml"
	shell:
		"""
		## Download and compress to bgzip on the fly
		curl {params.url} 2> {log} | zcat | bgzip -c > {output}
		"""

rule index_genome:
	input: rules.download_genome.output
	output: 
		fai = os.path.join(ref_path, ref_fa + ".fai"),
		gzi = os.path.join(ref_path, ref_fa + ".gzi")
	log: "workflow/logs/reference/index_genome.log"
	threads: 1
	conda: "../envs/samtools.yml"
	shell:
		"""
		samtools faidx \
		  --gzi-idx {output.gzi} \
		  --fai-idx {output.fai} \
		  {input}
		"""

rule remove_scaffolds:
	input: 
		fa = rules.download_genome.output,
		gzi = rules.index_genome.output.gzi
	output: 
		os.path.join(
			ref_path, species_upr + "." + ref_build + ".dna.chrom_only.fa.gz"
		)
	threads: 1
	conda: "../envs/samtools.yml"
	shell:
		"""
		samtools faidx {input.fa} \
			1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y | \
			gzip > {output}
		"""

rule download_transcriptome:
	input: 'config/config.yml'
	output: os.path.join(ref_path, trans_fa)
	params:
		url = trans_url
	log: "workflow/logs/reference/download_transcriptome.log"
	threads: 1
	shell:
		"""
		curl {params.url} 2> {log} | zcat | bgzip -c > {output}
		"""

rule index_transcriptome:
	input: rules.download_transcriptome.output
	output: 
		fai = os.path.join(ref_path, trans_fa + ".fai"),
		gzi = os.path.join(ref_path, trans_fa + ".gzi")
	log: "workflow/logs/reference/index_transcriptome.log"
	threads: 1
	conda: "../envs/samtools.yml"
	shell:
		"""
		samtools faidx \
		  --gzi-idx {output.gzi} \
		  --fai-idx {output.fai} \
		  {input}
		"""

rule remove_scaffold_transcripts:
	input: 
		fa = rules.download_transcriptome.output,
		gzi = rules.index_transcriptome.output.gzi
	output: 
		ids = os.path.join(ref_path, "chr_ids.txt"),
		fa = os.path.join(
			ref_path, species_upr + "." + ref_build + ".cdna.chrom_only.fa.gz"
		)
	params:
		regexp = '^>.+' + ref_build + ':[0-9XYM]'
	threads: 1
	conda: "../envs/samtools.yml"
	shell:
		"""
		zcat {input.fa} | \
			egrep "{params.regexp}" | \
			cut -f1 -d\ | \
			sed -r 's/^>//g' > {output.ids}
		samtools faidx \
		  -r {output.ids} \
		  {input.fa} | \
		  bgzip -c > {output.fa}
		"""

rule download_gtf:
	input: 'config/config.yml'
	output: os.path.join(ref_path, ref_gtf)
	params:
		url = gtf_url
	log: "workflow/logs/reference/download_gtf.log"
	threads: 1
	shell:
		"""
		curl -o {output} {params.url} 2> {log}
		"""

rule make_decoys:
	input: ancient(rules.remove_scaffolds.output)
	output: os.path.join(ref_path, "decoys.txt")
	threads: 1
	shell:
		"""
		grep "^>" <(gunzip -c {input}) | cut -d " " -f 1 > {output}
		sed -i.bak -e 's/>//g' {output}
		"""

rule make_gentrome:
	input: 
		ref_fa = ancient(rules.remove_scaffolds.output),
		trans_fa = ancient(rules.remove_scaffold_transcripts.output.fa)
	output: os.path.join(ref_path, "gentrome.fa.gz")
	threads: 1
	shell:
		"""
		cat {input.trans_fa} {input.ref_fa} > {output}
		"""

rule index_reference:
	input:
		gentrome = rules.make_gentrome.output,
		decoys = rules.make_decoys.output
	output: directory(os.path.join(ref_path, "salmon_index"))
	threads: 12
	conda: "../envs/salmon.yml" 
	log: "workflow/logs/salmon/salmon_index.log"
	shell:
		"""
		salmon index \
			-t {input.gentrome} \
			-d {input.decoys} \
			-p {threads} \
			-i {output} 2> {log}
		"""