process NANOPLOT_SUMMARY {
    label 'process_low'
    container 'docker://staphb/nanoplot:1.48.0'
    publishDir "${params.outdir}/read_qc", mode: 'copy'

    input:
    path stats                                  // all per-sample *_NanoStats.txt, collected

    output:
    path "nanoplot_summary.tsv"

    script:
    """
    # NanoStats is long (metric<TAB>value); transpose to one WIDE row per sample
    awk -F'\\t' '
      FNR==1 { s=FILENAME; sub(/_NanoStats\\.txt\$/,"",s); sub(/.*\\//,"",s); samples[++ns]=s }
      \$1=="Metrics" || \$1=="" { next }
      { val[ns SUBSEP \$1]=\$2; if(!(\$1 in seen)){seen[\$1]=1; order[++nm]=\$1} }
      END {
        printf "sample"; for(i=1;i<=nm;i++) printf "\\t%s", order[i]; printf "\\n"
        for(j=1;j<=ns;j++){ printf "%s", samples[j];
          for(i=1;i<=nm;i++){ k=j SUBSEP order[i]; printf "\\t%s", (k in val ? val[k] : "NA") } printf "\\n" }
      }
    ' ${stats} > nanoplot_summary.tsv
    """
}
