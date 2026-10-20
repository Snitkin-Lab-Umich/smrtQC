process MULTIQC {
    label 'process_low'
    container 'quay.io/biocontainers/multiqc:1.25--pyhdfd78af_0'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path '*'

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data"       , emit: data

    script:
    """
    multiqc . -n multiqc_report.html
    """
}
