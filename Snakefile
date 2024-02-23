"""
Truvari Analysis Pipeline
Snakefile for running Truvari bench and refine steps on multiple samples.

Pipeline version: 1.2.0
Author: ND Olson
Creation Date: 2023-04-26
Updated: 2024-02-11

Developed with assistance from OpenAI's ChatGPT (GPT-4), Knowledge cutoff: 2021-09

CHANGELOG
- v1.4.0: Adding functionality to get stratified benchmarking metrics
- v1.3.0: Only running truvari refine on phased vcfs - as defined in config, with seperate summary tables
- v1.2.0: Revised refine step to use candidate refine bed and 
- v1.1.0: Added functionality to run with and without regions bed for truvari refile step
"""

import pandas as pd
import os

PIPELINE_VERSION = "1.4.0"

configfile: "config.json"

# Assuming 'contexts.tsv' contains the genomic contexts and bed file paths
strats_df = pd.read_csv(config["strats_tsv"], sep='\t', header=None, names=['strat_id', 'bed_path'])
strats_dir = os.path.dirname(config["strats_tsv"])

# Adjust bed paths to have the same root directory as "contexts.tsv"
strats_df['bed_path'] = strats_df['bed_path'].apply(lambda x: os.path.join(strats_dir, x))

# Convert DataFrame to a dictionary for easy access in Snakemake
strats_dict = strats_df.set_index('strat_id').to_dict()['bed_path']

samples_to_apply_refine= [
    sample_name for sample_name, sample_details in config["samples"].items()
    if sample_details["refine"]
]

rule all:
    input:
        expand(
            [
                "bench_results/{sample}/summary.json",
                "bench_results/{sample}_bench_summary_report.csv",
            ],
            sample=config["samples"].keys(),
        ),
        expand(
            [
                "bench_results/{sample}/refine.variant_summary.json",
                "bench_results/{sample}_refine_summary_report.csv",
                "summary_reports/{sample}_stratified_metrics.csv",
            ],
            sample=samples_to_apply_refine,
        ),
	    "summary_reports/combined_summary_report.csv"

rule truvari_bench:
    input:
        base_vcf=config["base_vcf"],
        base_bed=config["base_bed"],
        input_vcf=lambda wildcards: config["samples"][wildcards.sample]["input_vcf"],
    output:
        json="bench_results/{sample}/summary.json",
        candidate_bed="bench_results/{sample}/candidate.refine.bed"
    params: 
        bench_output="bench_results/{sample}"
    shell:
        """
        rm -rf {params.bench_output}
        truvari bench \
            -b {input.base_vcf} \
            -c {input.input_vcf} \
            --includebed {input.base_bed} \
            --sizemin 50 --pick ac \
            -o {params.bench_output}
        """

rule truvari_refine:
    input:
        json="bench_results/{sample}/summary.json",
        region_bed="bench_results/{sample}/candidate.refine.bed",
        ref=config["ref"]
    output:
        json="bench_results/{sample}/refine.variant_summary.json",
        phab_json="bench_results/{sample}/phab_bench/summary.json",
    params: 
        bench_output="bench_results/{sample}/phab_bench"
    threads: 20
    run:
        cmd = (
            "rm -rf {params.bench_output} && "
            "truvari refine --threads {threads}"
            "   --recount"
            "	--use-region-coords"
        	"   --use-original-vcfs"
            "   --align mafft"
            "   --use-original"
            "   --reference {input.ref}"
        )

        if input.region_bed:
            cmd += " --regions {input.region_bed}"
        
        cmd += "    bench_results/{wildcards.sample}/"
        shell(cmd)

rule generate_bench_summary_report:
    input:
        "bench_results/{sample}/summary.json"
    output:
        csv="bench_results/{sample}_bench_summary_report.csv"
    run:
        import json
        import pandas as pd
        
        # Read the input summary.json file
        with open(input[0], "r") as f:
            summary_data = json.load(f)
        
        # Remove 'gt_matrix' and 'weighted' keys from the summary data
        summary_data.pop('gt_matrix', None)  # Removes 'gt_matrix' if it exists, does nothing otherwise
        summary_data.pop('weighted', None)  # Removes 'weighted' if it exists, does nothing otherwise


        # Convert the summary data to a Pandas DataFrame
        summary_df = pd.DataFrame([summary_data])

        # Save the summary report as a CSV file
        summary_df.to_csv(output.csv, index=False)

rule generate_refine_summary_report:
    input:
        "bench_results/{sample}/refine.variant_summary.json"
    output:
        csv="bench_results/{sample}_refine_summary_report.csv"
    run:
        import json
        import pandas as pd
        
        # Read the input summary.json file
        with open(input[0], "r") as f:
            summary_data = json.load(f)

        # Convert the summary data to a Pandas DataFrame
        summary_df = pd.DataFrame([summary_data])

        # Save the summary report as a CSV file
        summary_df.to_csv(output.csv, index=False)

rule combine_summary_reports:
    input:
        bench_reports=expand(
            "bench_results/{sample}_bench_summary_report.csv",
            sample=config["samples"].keys(),
        ),
        refine_reports=expand(
            "bench_results/{sample}_refine_summary_report.csv",
            sample=samples_to_apply_refine,
        ),
    output:
        csv="summary_reports/combined_summary_report.csv"
    run:
        import pandas as pd
        import os

        # Helper function to extract ID from the file path
        def extract_id_from_filename(file_path, bench_method):
            base_name = os.path.basename(file_path)  # get just the file name
            return base_name.replace(f"_{bench_method}_summary_report.csv", '')  # remove the suffix

        # Read and combine the individual summary reports with IDs
        summary_dfs = []
        for file in input.bench_reports + input.refine_reports:
            df = pd.read_csv(file)
            filename=os.path.basename(file)
            if "bench" in filename:
                df['bench_method'] = "bench"
                df['ID'] = extract_id_from_filename(file, "bench")
            elif "refine" in filename:
                df['bench_method'] = "refine"
                df['ID'] = extract_id_from_filename(file, "refine")
            summary_dfs.append(df)

        combined_df = pd.concat(summary_dfs)

        # Save the combined summary report as a CSV file
        combined_df.to_csv(output.csv, index=False)

rule truvari_stratify:
    input: 
        bench="bench_results/{sample}/phab_bench/summary.json",
        strat=lambda wildcards: strats_dict[wildcards.strat_id],
    output:
        bed="stratified_results/{sample}/{strat_id}.bed",
    params:
        bench_dir=lambda wc, input: os.path.dirname(input.bench)
    shell: """
        truvari stratify \
            {input.strat} \
            {params.bench_dir} \
            -o {output.bed}   
    """

# Calculate performance metrics for each stratified context
rule calculate_stratified_metrics:
    input:
        bed="stratified_results/{sample}/{strat_id}.bed"
    output:
        metrics="stratified_results/{sample}/{strat_id}_metrics.csv"
    run:
        import pandas as pd
        import truvari

        df = pd.read_csv(input.bed, sep='\t')

        # If the input.bed didn't have a header and so we couldn't use the `--header` parameter, we need to name columns
        df.columns = ['chrom', 'start', 'end', 'tpbase', 'tp', 'fn', 'fp']

        # Sum the columns of interest
        sums = df[["tpbase", "tp", "fn", "fp"]].sum()

        # Calculate precision, recall, and f1 scores based on the sums
        precision, recall, f1 = truvari.performance_metrics(sums['tpbase'], sums['tp'], sums['fn'], sums['fp'])

        # Create a DataFrame to store the summed metrics
        summed_metrics = pd.DataFrame([{'precision': precision, 'recall': recall, 'f1': f1, 'tpbase': sums['tpbase'], 'tp' : sums['tp'], 'fn': sums['fn'], 'fp': sums['fp']}])

        # Print prints
        summed_metrics.to_csv(output.metrics, index=False)

rule combine_stratified_metrics:
    input:
        metrics=expand("stratified_results/{{sample}}/{strat_id}_metrics.csv", strat_id=strats_dict.keys())
    output:
        combined="summary_reports/{sample}_stratified_metrics.csv"
    run:
        import pandas as pd

        # Initialize an empty DataFrame to hold combined metrics
        combined_metrics = pd.DataFrame()

        # Iterate over each metrics file and append it to the combined DataFrame
        for metrics_file in input.metrics:
            # Read the current metrics file
            df = pd.read_csv(metrics_file)

            # Extract strat_id from the file name for identification
            strat_id = metrics_file.split('/')[-1].replace('_metrics.csv', '')

            # Add a column for strat_id
            df['strat_id'] = strat_id

            # Append the current DataFrame to the combined DataFrame
            combined_metrics = pd.concat([combined_metrics, df], ignore_index=True)

        # Save the combined metrics to a CSV file
        combined_metrics.to_csv(output.combined, index=False)
