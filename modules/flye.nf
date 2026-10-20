process FLYE {
    tag   "$meta.id"
    label 'process_high'
    container 'docker://staphb/flye:2.9.6'
    publishDir "${params.outdir}/assembly/flye/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}_flye.fasta")  , emit: assembly   // circularity in headers
    path  "${meta.id}_flye_assembly_info.txt"       , emit: info

    script:
    // -g uses THIS sample's genome size from the samplesheet (per-species), not a global default
    """
    flye --pacbio-hifi ${reads} -g ${meta.genome_size} -t ${task.cpus} -o flye

    cp flye/assembly_info.txt ${meta.id}_flye_assembly_info.txt

    # add circularity to each contig header:  >{sample}_{contig};circular={true|false}
    # (circ. is column 4 of Flye's assembly_info.txt)
    awk -v s="${meta.id}" '
        FNR==NR { if (FNR>1) circ[\$1] = (\$4=="Y") ? "true" : "false"; next }
        /^>/    { name = substr(\$1,2); print ">" s "_" name ";circular=" (name in circ ? circ[name] : "false"); next }
                { print }
    ' flye/assembly_info.txt flye/assembly.fasta > ${meta.id}_flye.fasta
    """
}
