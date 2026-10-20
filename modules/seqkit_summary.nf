process SEQKIT_SUMMARY {
    label 'process_low'
    container 'docker://staphb/seqkit:2.13.0'
    publishDir "${params.outdir}/read_qc", mode: 'copy'

    input:
    path tsvs                                   // all per-sample .seqkit.tsv, collected

    output:
    path "seqkit_summary.tsv"

    script:
    """
    # header from the first file, then every data row (skip repeated headers)
    awk 'FNR==1 && NR!=1 {next} {print}' ${tsvs} > seqkit_summary.tsv
    """
}
