process BUSCO {
    tag   "${meta.id}_${meta.assembler}"
    label 'process_medium'
    // label 'qc_tolerant'
    container 'docker://staphb/busco:5.8.2-prok-bacteria_odb12_2024-11-14'
    publishDir "${params.outdir}/assembly_qc/busco", mode: 'copy'

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("busco_${meta.id}_${meta.assembler}")   , emit: results
    path  "busco_${meta.id}_${meta.assembler}/short_summary*.txt" , emit: summary

    script:
    // bacteria_odb12 baked into the container tag -> offline, no --download_path. Retry x2.
    """
    set -e
    for i in 1 2; do
        echo "Attempt \$i: BUSCO on ${meta.id}_${meta.assembler}"
        busco -f -i ${assembly} -m genome -l bacteria_odb10 \\
            -c ${task.cpus} -o busco_${meta.id}_${meta.assembler} && break || echo "BUSCO attempt \$i failed"
        sleep 10
    done
    ls busco_${meta.id}_${meta.assembler}/short_summary*.txt >/dev/null 2>&1 \\
        || { echo "BUSCO failed after 2 attempts" >&2; exit 1; }
    """
}
