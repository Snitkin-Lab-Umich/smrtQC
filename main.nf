#!/usr/bin/env nextflow
/*
 * pacbio-hifi-wgs
 * LongPlex PacBio HiFi -> per-isolate bacterial assembly, QC and annotation.
 *
 * Input is the DEMULTIPLEXED per-isolate FASTQs. Adapters and
 * barcodes were already removed upstream by the core (ccs --knrt-ada, pbtrim,
 * lima SYMMETRIC-ADAPTERS), so there is no HiFiAdapterFilt step here by default.
 */

nextflow.enable.dsl = 2

// ---- modules ---------------------------------------------------------------
include { SEQKIT_STATS     } from './modules/seqkit_stats'
include { NANOPLOT         } from './modules/nanoplot'
include { SEQKIT_SUMMARY   } from './modules/seqkit_summary'
include { NANOPLOT_SUMMARY } from './modules/nanoplot_summary'
// include { CHOPPER      } from './modules/local/chopper'
include { HIFIASM      } from './modules/hifiasm'
include { FLYE         } from './modules/flye'
include { QUAST        } from './modules/quast'
include { BUSCO        } from './modules/busco'
// include { CHECKM2      } from './modules/local/checkm2'
include { SKANI        } from './modules/skani'
include { MLST         } from './modules/mlst'
include { QC_REPORT } from './modules/qc_report'
// include { BAKTA        } from './modules/local/bakta'
// include { MULTIQC      } from './modules/local/multiqc'

// ---- help / param checks ---------------------------------------------------
if (params.input == null) {
    exit 1, "ERROR: --input samplesheet.csv is required (columns: sample,fastq). See assets/samplesheet.csv"
}

workflow {

    // ------------------------------------------------------------------ input
    // samplesheet -> channel of [ meta, reads ]
    // meta is an nf-core-style map; keep the full sample id (incl. -ORGn) unique.
    ch_reads = Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            if (!row.sample || !row.fastq) exit 1, "Bad samplesheet row: ${row}"
            def meta = [
                id          : row.sample,
                organism    : row.organism ?: 'NA',
                genome_size : (row.genome_size ?: params.expected_genome_size) as long
            ]
            tuple(meta, file(row.fastq, checkIfExists: true))
        }

    // --------------------------------------------------------------- read QC
    SEQKIT_STATS(ch_reads)          // per-sample stats + HiFi depth estimate vs expected_genome_size
    NANOPLOT(ch_reads)

     // summaries include every sample that produced stats
    SEQKIT_SUMMARY  ( SEQKIT_STATS.out.stats.map { meta, f -> f }.collect() )
    NANOPLOT_SUMMARY( NANOPLOT.out.stats.collect() )
    // ------------------------------------------- optional length/quality trim
    // if (params.skip_filter) {
    //     ch_asm_in = ch_reads
    // } else {
    //     CHOPPER(ch_reads)
    //     ch_asm_in = CHOPPER.out.reads
    // }

    // --- OPTIONAL coverage gate (uncomment to drop low-depth isolates before assembly) ---
    // ch_asm_in = ch_asm_in
    //     .join(SEQKIT_STATS.out.coverage)
    //     .filter { meta, reads, depth -> (depth as Float) >= params.min_coverage_warn }
    //     .map { meta, reads, depth -> tuple(meta, reads) }

    // --------------------------------------------------------------- assembly
    // real isolates only into assembly (keeps blanks/kit out of Flye/hifiasm)
    ch_isolates = ch_reads.filter { meta, reads -> meta.organism != 'NA' }

    HIFIASM(ch_isolates)  // primary assembler (HiFi-native)
    FLYE(ch_isolates) // independent cross-check; FLYE.out.info has circular= flags

    // stamp each assembly with its source, then merge into one channel
    ch_asm = HIFIASM.out.assembly.map { meta, fa -> tuple(meta + [assembler: 'hifiasm'], fa) }
        .mix( FLYE.out.assembly.map   { meta, fa -> tuple(meta + [assembler: 'flye'],    fa) } )
    // ----------------------------------------------------------- assembly QC
    QUAST(ch_asm)
    // BUSCO(ch_asm)
    SKANI(ch_asm)
    MLST(ch_asm)
    // CHECKM2(ch_assembly)
    
    // -------------------------------------------------------------- annotation
    // BAKTA(ch_assembly)

    // ----------------------------------------------------------------- MultiQC
    // ch_multiqc = SEQKIT_STATS.out.stats.map { meta, f -> f }
    //     .mix( NANOPLOT.out.stats )
    //     .mix( QUAST.out.report )
    //     .mix( BUSCO.out.summary )
    //     .mix( CHECKM2.out.report.map { meta, f -> f } )
    //     .collect()
    // MULTIQC(ch_multiqc)

    // ----------------------------------------------------------- final QC report
    QC_REPORT(
        Channel.fromPath(params.input, checkIfExists: true),
        NANOPLOT_SUMMARY.out,
        QUAST.out.report.map { meta, f -> f }.collect(),
        SKANI.out.report.map { meta, f -> f }.collect(),
        MLST.out.report.map  { meta, f -> f }.collect(),   
        FLYE.out.info.collect()
    )
}

workflow.onComplete {
    log.info ( workflow.success
        ? "\nDone. Results in ${params.outdir}\n"
        : "\nFinished with errors. Check ${params.outdir}/pipeline_info/\n" )
}
