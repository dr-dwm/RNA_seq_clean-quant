import glob
import os

# ==========================
# Configuration
# ==========================
DATA_DIR = "/mnt/ffs24/home/maddock9/rna_seq_workflow/01.RawData"  # folder containing .fq.gz files
SALMON_INDEX = "/mnt/ffs24/home/maddock9/rna_seq_workflow/salmon_index"
RESULTS_DIR = "quantification_results"

# Ensure results directory exists
if not os.path.exists(RESULTS_DIR):
    os.makedirs(RESULTS_DIR)
    print(f"DEBUG: Created {RESULTS_DIR}/ folder")

# Automatically find all paired-end RNA-Seq files
# Assumes files are named like: sample1_1.fq.gz, sample1_2.fq.gz
r1_files = glob.glob(os.path.join(DATA_DIR, "*_1.fq.gz"))
samples = [os.path.basename(f).replace("_1.fq.gz", "") for f in r1_files]

print(f"DEBUG: Found RNA-Seq samples: {samples}")
if not samples:
    raise ValueError(f"No *_1.fq.gz RNA-Seq files found in {DATA_DIR}. Please check the path.")

# ==========================
# Rule: all (final targets)
# ==========================
rule all:
    input:
        expand(f"{RESULTS_DIR}/{{sample}}_quant.sf", sample=samples)

# ==========================
# Step 1: filter and trim reads with fastp (Conda environment)
# ==========================
rule filter_file:
    input:
        fq_file1=lambda wildcards: f"{DATA_DIR}/{wildcards.sample}_1.fq.gz",
        fq_file2=lambda wildcards: f"{DATA_DIR}/{wildcards.sample}_2.fq.gz"
    output:
        filtered_fq1=f"{RESULTS_DIR}/{{sample}}_filtered_1.fq.gz",
        filtered_fq2=f"{RESULTS_DIR}/{{sample}}_filtered_2.fq.gz",
        qc_html=f"{RESULTS_DIR}/{{sample}}_fastp.html",
        qc_json=f"{RESULTS_DIR}/{{sample}}_fastp.json"
    conda:
        "envs/env_fastp.yaml"
    shell:
        """
        echo "DEBUG: Filtering {input.fq_file1} and {input.fq_file2} with fastp"
        fastp -i {input.fq_file1} -I {input.fq_file2} \
              -o {output.filtered_fq1} -O {output.filtered_fq2} \
              -q 20 -u 50 -n 10 -l 36 \
              -h {output.qc_html} \
              -j {output.qc_json} \
              -w 8
        """

# ==========================
# Step 2: Remove rRNA reads with ribodetector (Conda environment)
# ==========================
rule remove_rrna:
    input:
        filtered_fq1=f"{RESULTS_DIR}/{{sample}}_filtered_1.fq.gz",
        filtered_fq2=f"{RESULTS_DIR}/{{sample}}_filtered_2.fq.gz"
    output:
        rrna_removed_fq1=f"{RESULTS_DIR}/{{sample}}_rrna_removed_1.fq.gz",
        rrna_removed_fq2=f"{RESULTS_DIR}/{{sample}}_rrna_removed_2.fq.gz"
    conda:
        "envs/env_ribodetector.yaml"
    shell:
        """
        echo "DEBUG: Removing rRNA from {input.filtered_fq1} and {input.filtered_fq2} with ribodetector"
        ribodetector_cpu -t 20 \
        -l 149 \
        -i {input.filtered_fq1} {input.filtered_fq2} \
        -e norrna \
        --chunk_size 256 \
        -o {output.rrna_removed_fq1} {output.rrna_removed_fq2}
        """

# ==========================
# Step 3: Quantify expression with Salmon (HPC module)
# ==========================
rule quantify_expression:
    input:
        rrna_removed_fq1=f"{RESULTS_DIR}/{{sample}}_rrna_removed_1.fq.gz",
        rrna_removed_fq2=f"{RESULTS_DIR}/{{sample}}_rrna_removed_2.fq.gz"
    output:
        quant_file=f"{RESULTS_DIR}/{{sample}}_quant.sf"
    shell:
        """
        echo "DEBUG: Loading HPC modules for Salmon"
        module purge
        module load Miniforge3/24.3.0-0
        module load Salmon/1.10.1-GCC-12.3.0

        echo "DEBUG: Quantifying expression for {input.rrna_removed_fq1} and {input.rrna_removed_fq2} with Salmon"
        salmon quant -i {SALMON_INDEX} \
                      -l A \
                      -1 {input.rrna_removed_fq1} \
                      -2 {input.rrna_removed_fq2} \
                      -p 8 \
                      --validateMappings \
                      -o {RESULTS_DIR}/{{wildcards.sample}}_salmon_out

        cp {RESULTS_DIR}/{{wildcards.sample}}_salmon_out/quant.sf {output.quant_file}
        """
