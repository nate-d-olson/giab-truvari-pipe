# Truvari SV Evaluation Pipeline

This Snakemake pipeline is designed to benchmark SV VCF files using the Truvari `bench` and `refine` commands.
The pipeline generates a summary report in CSV format and a README file in Markdown format containing the summary report as a table.

## Pipeline Overview

1. **Truvari bench**: Compares the base VCF files with the comparison VCF files using the `truvari bench` command. The output consists of a VCF file containing the benchmark results and an accompanying TBI index file.
2. **Truvari refine**: Refines the benchmark VCF files using the `truvari refine` command. The output consists of a refined VCF file and an accompanying TBI index file.
3. **Generate summary report**: Collects the summary information from the `summary.json` files and `refine.variant_summary.json` generated by the Truvari bench and refine, respectively, commands and creates a summary report in CSV format.
4. **Generate README**: Creates a README file in Markdown format that includes the summary report as a Markdown table.

## Run Information

- Date of run: {date_of_run}
- Snakemake version: {snakemake_version}
- Pipeline version: {pipeline_version}

## Dependencies

- Truvari: {truvari_version}
- Pandas: {pandas_version}
- Tabulate: {tabulate_version}

## Summary Report

The table below summarizes the results from the Truvari analysis:
{summary_table}