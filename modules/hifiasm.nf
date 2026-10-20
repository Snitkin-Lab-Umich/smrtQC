process HIFIASM {
    tag   "$meta.id"
    label 'process_high'
    container 'docker://staphb/hifiasm:0.25.0'
    publishDir "${params.outdir}/assembly/hifiasm/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}_hifiasm.fasta"), emit: assembly
    path  "${meta.id}.bp.*.gfa"                      , emit: graphs

    script:
    // Default (HiFi) mode; small bacterial genomes need no special flags.
    """
    hifiasm -o ${meta.id} -t ${task.cpus} ${reads}
    # primary-contig graph -> FASTA
    awk '/^S/{ print ">"\$2"\\n"\$3 }' ${meta.id}.bp.p_ctg.gfa > ${meta.id}_hifiasm.fasta
    """
}
