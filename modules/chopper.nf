process CHOPPER {
    tag   "$meta.id"
    label 'process_low'
    container 'quay.io/biocontainers/chopper:0.9.0--hdcf5f25_0'
    publishDir "${params.outdir}/read_qc/filtered", mode: 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.filt.fastq.gz"), emit: reads

    script:
    // HiFi is already Q20+; this is a light safety filter (drop short/sub-Q20 reads).
    """
    gunzip -c ${reads} | chopper -q 20 -l 1000 --threads ${task.cpus} | gzip > ${meta.id}.filt.fastq.gz
    """
}
