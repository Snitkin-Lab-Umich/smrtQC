process BAKTA {
    tag   "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/bakta:1.9.4--pyhdfd78af_0'
    publishDir "${params.outdir}/annotation/bakta", mode: 'copy'

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("bakta_${meta.id}"), emit: annotation

    script:
    """
    bakta --db ${params.bakta_db} --threads ${task.cpus} \\
        --prefix ${meta.id} --output bakta_${meta.id} \\
        ${params.bakta_args} ${assembly}
    """
}
