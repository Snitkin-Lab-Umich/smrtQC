process SEQKIT_STATS {
    tag   "$meta.id"
    label 'process_low'
    label 'qc_tolerant'          // keep for the 151-sample run: one bad sample won't block the summary
    container 'docker://staphb/seqkit:2.13.0'
    publishDir "${params.outdir}/read_qc/seqkit/${meta.id}", mode: 'copy'   // per-sample folder

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.seqkit.tsv"), emit: stats

    script:
    """
    seqkit stats -a -T ${reads} > raw.tsv

    # estimate HiFi depth from sum_len (col 5) and THIS sample's genome size
    bases=\$(awk 'NR==2{print \$5}' raw.tsv)
    depth=\$(awk -v b=\$bases -v g=${meta.genome_size} 'BEGIN{printf "%.1f", b/g}')
    flag=\$(awk -v d=\$depth -v m=${params.min_coverage_warn} 'BEGIN{print (d<m)?"NOT OK":"OK"}')

    # prepend a sample column, append est_depth + FLAG  (one tidy per-sample row)
    awk -v s="${meta.id}" -v d="\$depth" -v f="\$flag" 'BEGIN{OFS="\\t"}
        NR==1{print "sample",\$0,"est_depth","FLAG"}
        NR==2{print s,\$0,d,f}' raw.tsv > ${meta.id}.seqkit.tsv
    """
}
