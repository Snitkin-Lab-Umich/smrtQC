process CHECKM2 {
    tag   "$meta.id"
    label 'process_medium'
    label 'qc_tolerant'
    container 'quay.io/biocontainers/checkm2:1.0.2--pyh7cba7a3_0'
    publishDir "${params.outdir}/assembly_qc/checkm2", mode: 'copy'

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("checkm2_${meta.id}/quality_report.tsv"), emit: report

    script:
    """
    checkm2 predict --threads ${task.cpus} -x fasta \\
        --input ${assembly} \\
        --output-directory checkm2_${meta.id} \\
        --database_path ${params.checkm2_db}
    """
}
