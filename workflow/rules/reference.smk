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
	shell:
		"""
		curl -o {output} {params.url} 2> {log}
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
		curl -o {output} {params.url} 2> {log}
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
	input: ancient(rules.download_genome.output)
	output: os.path.join(ref_path, "decoys.txt")
	threads: 1
	shell:
		"""
		grep "^>" <(gunzip -c {input}) | cut -d " " -f 1 > {output}
		sed -i.bak -e 's/>//g' {output}
		"""

rule make_gentrome:
	input: 
		ref_fa = ancient(rules.download_genome.output),
		trans_fa = ancient(rules.download_transcriptome.output)
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