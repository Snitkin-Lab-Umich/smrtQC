#!/usr/bin/env bash
# Build a Nextflow samplesheet by joining the FASTQ dir with an organism-ID CSV.
#
#   bin/make_samplesheet.sh <fastq_dir> <organism_csv> > assets/samplesheet.csv
#
# Output columns: sample,fastq,organism,genome_size
#  - EVERY *.fastq.gz in the dir is included (isolates + blanks + pool-kit wells)
#  - a lingering GMCF_<run>_<idx>_ prefix on an MBR isolate is stripped; other
#    names (blanks, kit wells, already-renamed MBRs) are kept verbatim
#  - organism looked up by sample id from <organism_csv> (cols: Sample_ID,Organism_ID)
#  - no organism row -> organism=NA, genome_size=DEFAULT_SIZE
#  - genome_size otherwise from the species map below (falls back to DEFAULT_SIZE)
set -euo pipefail

fastq_dir="${1:?usage: make_samplesheet.sh <fastq_dir> <organism_csv>}"
org_csv="${2:?usage: make_samplesheet.sh <fastq_dir> <organism_csv>}"
DEFAULT_SIZE=5000000          # keep in sync with params.expected_genome_size

declare -A GSIZE=(
    ["enterococcus faecium"]=3000000
    ["enterococcus faecalis"]=3000000
    ["escherichia coli"]=5000000
    ["klebsiella pneumoniae"]=5500000
    ["enterobacter cloacae"]=5300000
    ["enterobacter aerogenes"]=5300000
    ["klebsiella aerogenes"]=5300000
    ["acinetobacter baumannii"]=3900000
    ["morganella morganii"]=3900000
    ["proteus mirabilis"]=4000000
    ["providencia stuartii"]=4200000
    ["citrobacter farmeri"]=5000000
    ["citrobacter koseri"]=4800000
)

trim() { local s="${1//$'\r'/}"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

# load sample_id -> organism.  '|| [ -n "$sid" ]' processes a final line that
# lacks a trailing newline (otherwise the last CSV row is silently dropped).
declare -A ORG
while IFS=, read -r sid org _rest || [ -n "$sid" ]; do
    sid="$(trim "$sid")"; org="$(trim "$org")"
    [ -z "$sid" ] || [ "$sid" = "Sample_ID" ] && continue
    ORG["$sid"]="$org"
done < "$org_csv"

echo "sample,fastq,organism,genome_size"
for f in "$fastq_dir"/*.fastq.gz; do
    [ -e "$f" ] || { echo "no fastq.gz in $fastq_dir" >&2; exit 1; }
    base="$(basename "$f" .fastq.gz)"
    case "$base" in
        *_MBR*) sample="MBR${base##*_MBR}" ;;   # isolate still carrying GMCF prefix
        *)      sample="$base" ;;                # renamed MBRs, blanks, kit wells: verbatim
    esac

    org="${ORG[$sample]:-}"
    if [ -z "$org" ]; then
        org="NA"; size="$DEFAULT_SIZE"
    else
        size="${GSIZE[$(trim "${org,,}")]:-$DEFAULT_SIZE}"
    fi
    printf "%s,%s,%s,%s\n" "$sample" "$(readlink -f "$f")" "$org" "$size"
done