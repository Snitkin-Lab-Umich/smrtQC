process QC_REPORT {
    label 'process_low'
    container 'docker://staphb/nanoplot:1.48.0'   // ships python3 + pandas
    publishDir "${params.outdir}/report", mode: 'copy'

    input:
    path samplesheet
    path nanoplot_summary
    path quast_files, stageAs: 'quast/*'
    path skani_files, stageAs: 'skani/*'
    path mlst_files,  stageAs: 'mlst/*'
    path flye_infos,  stageAs: 'flye/*'

    output:
    path "QC_report.csv"

    script:
    """
    make_qc_report.py \\
        --samplesheet ${samplesheet} \\
        --nanoplot ${nanoplot_summary} \\
        --quast-dir quast \\
        --skani-dir skani \\
        --mlst-dir mlst \\
        --flye-dir flye \\
        --min-coverage ${params.min_coverage_warn} \\
        --max-contigs ${params.max_contigs} \\
        --out QC_report.csv
    """
}
