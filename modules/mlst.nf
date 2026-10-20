process MLST {
    tag   "${meta.id}_${meta.assembler}"
    label 'process_low'
    label 'qc_tolerant'          // typing annotation, not a QC gate -> don't halt the run on a weird assembly
    container 'docker://staphb/mlst:2.35.0'   // <-- pin to the tag your snakemake uses (PubMLST DB date matters)
    publishDir "${params.outdir}/assembly_qc/mlst", mode: 'copy', pattern: "${meta.id}/**"

    input:
    tuple val(meta), path(assembly)

    output:
    path "${meta.id}/${meta.assembler}/${meta.id}_mlst.tsv"       , emit: results  // published, nested
    tuple val(meta), path("${meta.id}_${meta.assembler}_mlst.tsv"), emit: report   // flat, for QC_REPORT

    script:
    // tseemann/mlst: TSV to stdout -> FILE  SCHEME  ST  allele(1) allele(2) ...
    """
    mkdir -p ${meta.id}/${meta.assembler}
    mlst ${assembly} > ${meta.id}/${meta.assembler}/${meta.id}_mlst.tsv
    cp ${meta.id}/${meta.assembler}/${meta.id}_mlst.tsv ${meta.id}_${meta.assembler}_mlst.tsv
    """
}
