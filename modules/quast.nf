process QUAST {
    tag   "${meta.id}_${meta.assembler}"
    label 'process_low'
    label 'qc_tolerant'
    container 'docker://staphb/quast:5.3.0'
    // publish only the nested dir tree -> assembly_qc/quast/<id>/<assembler>/...
    publishDir "${params.outdir}/assembly_qc/quast", mode: 'copy', pattern: "${meta.id}/**"

    input:
    tuple val(meta), path(assembly)

    output:
    path "${meta.id}/${meta.assembler}"                              , emit: results   // published, nested
    tuple val(meta), path("${meta.id}_${meta.assembler}.report.tsv"), emit: report    // flat, for QC_REPORT only

    script:
    """
    quast.py -o ${meta.id}/${meta.assembler} -t ${task.cpus} \\
        --est-ref-size ${meta.genome_size} ${assembly}
    # uniquely-named flat copy so the report step can tell samples/assemblers apart
    cp ${meta.id}/${meta.assembler}/report.tsv ${meta.id}_${meta.assembler}.report.tsv
    """
}
