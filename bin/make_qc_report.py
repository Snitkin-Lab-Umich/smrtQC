#!/usr/bin/env python3
"""Final QC summary report (one row per sample x assembler).

Flat per-report inputs:
  quast/<sample>_<assembler>.report.tsv
  skani/<sample>_<assembler>_skani.txt
  mlst/<sample>_<assembler>_mlst.tsv
  flye/<sample>_flye_assembly_info.txt      (flye rows only)
plus nanoplot_summary.tsv (per sample) and the samplesheet (organism).

coverage_vs_assembly        = total_bases / assembly_total_length
pct_circular_contigs_flye   = 100 * num_circular / num_contigs   (flye rows only)
qc_check = PASS if coverage > --min-coverage AND num_contigs < --max-contigs.
"""
import argparse, os, glob
import pandas as pd


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--samplesheet", required=True)
    p.add_argument("--nanoplot",    required=True)
    p.add_argument("--quast-dir",   required=True)
    p.add_argument("--skani-dir",   required=True)
    p.add_argument("--mlst-dir",    required=True)
    p.add_argument("--flye-dir",    required=True)
    p.add_argument("--min-coverage", type=float, default=30.0)
    p.add_argument("--max-contigs",  type=int,   default=20)
    p.add_argument("--out", required=True)
    return p.parse_args()


def load_samplesheet(path):
    df = pd.read_csv(path, dtype=str)
    return {str(r["sample"]): r.get("organism", "NA") for _, r in df.iterrows()}


def parse_quast(report_tsv):
    m = {}
    with open(report_tsv) as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                m[parts[0]] = parts[1]
    return m


def count_circular(flye_info):
    n = 0
    with open(flye_info) as f:
        for i, line in enumerate(f):
            if i == 0:
                continue
            c = line.rstrip("\n").split("\t")
            if len(c) > 3 and c[3] == "Y":
                n += 1
    return n


def parse_skani(path):
    try:
        df = pd.read_csv(path, sep="\t")
    except Exception:
        return {}
    if df.empty:
        return {}
    r = df.iloc[0]
    return {"skani_ANI": r.get("ANI", ""),
            "skani_AF_ref": r.get("Align_fraction_ref", ""),
            "skani_AF_query": r.get("Align_fraction_query", ""),
            "skani_top_ref": r.get("Ref_name", "")}


def parse_mlst(path):
    # tseemann/mlst: FILE <tab> SCHEME <tab> ST <tab> allele(1) ...  (no header)
    try:
        with open(path) as f:
            line = f.readline().rstrip("\n")
    except Exception:
        return {}
    if not line:
        return {}
    c = line.split("\t")
    return {"mlst_scheme": c[1] if len(c) > 1 else "",
            "mlst_ST":     c[2] if len(c) > 2 else ""}


def main():
    a = parse_args()
    organism_of = load_samplesheet(a.samplesheet)
    nano = pd.read_csv(a.nanoplot, sep="\t").set_index("sample")

    rows = []
    for report_tsv in sorted(glob.glob(os.path.join(a.quast_dir, "*.report.tsv"))):
        stem = os.path.basename(report_tsv)[:-len(".report.tsv")]   # <sample>_<assembler>
        sample, assembler = stem.rsplit("_", 1)

        q = parse_quast(report_tsv)
        n_contigs = q.get("# contigs", q.get("# contigs (>= 0 bp)", ""))
        asm_n50   = q.get("N50", "")
        total_len = q.get("Total length", q.get("Total length (>= 0 bp)", ""))

        nr = nano.loc[sample] if sample in nano.index else {}
        get = (lambda k: nr.get(k, "")) if hasattr(nr, "get") else (lambda k: "")
        nbases = get("number_of_bases")

        try:
            coverage = round(float(nbases) / float(total_len), 1)
        except Exception:
            coverage = ""

        circ = ""
        if assembler == "flye":
            fi = os.path.join(a.flye_dir, f"{sample}_flye_assembly_info.txt")
            if os.path.exists(fi):
                circ = count_circular(fi)

        pct_circ = ""
        try:
            if circ != "" and int(n_contigs) > 0:
                pct_circ = round(100 * int(circ) / int(n_contigs), 1)
        except Exception:
            pct_circ = ""

        sk_path = os.path.join(a.skani_dir, f"{sample}_{assembler}_skani.txt")
        sk = parse_skani(sk_path) if os.path.exists(sk_path) else {}

        ml_path = os.path.join(a.mlst_dir, f"{sample}_{assembler}_mlst.tsv")
        ml = parse_mlst(ml_path) if os.path.exists(ml_path) else {}

        qc = "FAIL"
        try:
            if coverage != "" and n_contigs != "" \
               and float(coverage) > a.min_coverage and int(n_contigs) < a.max_contigs:
                qc = "PASS"
        except Exception:
            qc = "FAIL"

        rows.append({
            "sample": sample,
            "assembler": assembler,
            "organism": organism_of.get(sample, "NA"),
            "number_of_reads": get("number_of_reads"),
            "number_of_bases": nbases,
            "mean_read_length": get("mean_read_length"),
            "read_n50": get("n50"),
            "est_depth_vs_genome_size": get("est_depth"),
            "num_contigs": n_contigs,
            "assembly_n50": asm_n50,
            "assembly_total_length": total_len,
            "num_circular_contigs_flye": circ,
            "pct_circular_contigs_flye": pct_circ,
            "coverage_vs_assembly": coverage,
            "mlst_scheme": ml.get("mlst_scheme", ""),
            "mlst_ST": ml.get("mlst_ST", ""),
            "skani_ANI": sk.get("skani_ANI", ""),
            "skani_AF_ref": sk.get("skani_AF_ref", ""),
            "skani_AF_query": sk.get("skani_AF_query", ""),
            "skani_top_ref": sk.get("skani_top_ref", ""),
            "qc_check": qc,
        })

    out = pd.DataFrame(rows)
    if not out.empty:
        out = out.sort_values(["sample", "assembler"])
    out.to_csv(a.out, index=False)
    print(f"Wrote {len(out)} rows to {a.out}")


if __name__ == "__main__":
    main()