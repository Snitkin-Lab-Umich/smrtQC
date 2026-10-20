process NANOPLOT {
    tag   "$meta.id"
    label 'process_low'
    label 'qc_tolerant'
    container 'docker://staphb/nanoplot:1.48.0'
    publishDir "${params.outdir}/read_qc/nanoplot", mode: 'copy'   // -> read_qc/nanoplot/<sample>/

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}")        , emit: dir     // the whole per-sample folder
    path "${meta.id}/${meta.id}_NanoStats.txt" , emit: stats   // for the summary

    script:
    """
    NanoPlot --fastq ${reads} -t ${task.cpus} --tsv_stats \\
        --prefix ${meta.id}_ -o ${meta.id}

    # append est_depth + FLAG so they ride into the summary alongside NanoPlot's metrics
    stats=${meta.id}/${meta.id}_NanoStats.txt
    bases=\$(awk -F'\\t' '\$1=="number_of_bases"{print \$2}' \$stats)
    depth=\$(awk -v b=\$bases -v g=${meta.genome_size} 'BEGIN{printf "%.1f", b/g}')
    flag=\$(awk -v d=\$depth -v m=${params.min_coverage_warn} 'BEGIN{print (d<m)?"NOT OK":"OK"}')
    printf "est_depth\\t%s\\nFLAG\\t%s\\n" "\$depth" "\$flag" >> \$stats
    """
}
