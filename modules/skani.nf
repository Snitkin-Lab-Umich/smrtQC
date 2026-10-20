process SKANI {
    tag   "${meta.id}_${meta.assembler}"
    label 'process_low'
    container 'docker://staphb/skani:0.2.2'   // matches the version that built the GTDB DB
    publishDir "${params.outdir}/assembly_qc/skani", mode: 'copy', pattern: "${meta.id}/**"

    input:
    tuple val(meta), path(assembly)

    output:
    path "${meta.id}/${meta.assembler}/${meta.id}_skani.txt"            , emit: results  // published, nested
    tuple val(meta), path("${meta.id}_${meta.assembler}_skani.txt")     , emit: report   // flat, for QC_REPORT

    script:
    // query is POSITIONAL for 'skani search'; -d = prebuilt GTDB sketch dir
    """
    mkdir -p ${meta.id}/${meta.assembler}
    skani search ${assembly} -d ${params.skani_db} \\
        -o ${meta.id}/${meta.assembler}/${meta.id}_skani.txt -t ${task.cpus} -n 5
    cp ${meta.id}/${meta.assembler}/${meta.id}_skani.txt ${meta.id}_${meta.assembler}_skani.txt
    """
}
