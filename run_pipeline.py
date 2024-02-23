#!/usr/bin/env python3
"""
run_pipeline.py

A script to run the Truvari Analysis Pipeline using a Snakemake pipeline,
generate a summary table from the results, and complete a template README.md
file with pipeline and run information.

This script was developed with assistance from ChatGPT, a large language model
trained by OpenAI based on the GPT-4 architecture.

Usage:
    python run_pipeline.py [--skip-pipeline]

Options:
    --skip-pipeline  Skip running the Snakemake pipeline and generate the summary table and README.md only.

Author: ND Olson nolson@nist.gov
Date: 2023-04-26
Version: 1.0.0
"""

import os
import sys
import subprocess
import pandas as pd
from tabulate import tabulate
from datetime import datetime
import pkg_resources
import argparse


def run_snakemake_pipeline():
    """
    Run the Snakemake pipeline and check for successful completion. If the
    pipeline fails, print the error message and exit the script.
    """
    print("Running the Snakemake pipeline...")
    with subprocess.Popen(
        ["snakemake", "--cores", "20", "--verbose", "--rerun-incomplete"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    ) as process:
        for line in process.stdout:
            sys.stdout.write(line)
        for line in process.stderr:
            sys.stderr.write(line)

        process.wait()
        if process.returncode != 0:
            print("Snakemake pipeline failed.")
            sys.exit(1)


def generate_summary_table():
    """
    Load the combined_summary_report.csv file, convert it to a Markdown table,
    and return the table as a string.

    Returns:
        str: Markdown-formatted summary table.
    """
    summary_file = "summary_reports/combined_summary_report.csv"
    if not os.path.isfile(summary_file):
        print(f"Error: {summary_file} not found.")
        sys.exit(1)

    print("Loading the combined_summary_report.csv file...")
    try:
        combined_summary_report = pd.read_csv(summary_file)
    except Exception as e:
        print(f"Error loading {summary_file}: {e}")
        sys.exit(1)

    print("Converting the combined_summary_report DataFrame to a Markdown table...")
    return tabulate(combined_summary_report, tablefmt="pipe", headers="keys", floatfmt=".4f", showindex=False)


def generate_readme(summary_table):
    """
    Fill in the template README.md file with pipeline and run information,
    including the provided summary table. Write the completed README.md file
    to disk.

    Args:
        summary_table (str): Markdown-formatted summary table to include in the README.md file.
    """
    template_file = "README-eval-template.md"
    output_file = "giab-evaluation-README.md"

    if not os.path.isfile(template_file):
        print(f"Error: {template_file} not found.")
        sys.exit(1)

    print("Filling in the template README.md with pipeline and run information...")
    date_of_run = datetime.now().strftime("%Y-%m-%d")
    pipeline_name = "Truvari Analysis"
    snakemake_version = pkg_resources.get_distribution("snakemake").version
    pipeline_version = "1.2.0"
    truvari_version = "v4.2.2-dev"  # Manually obtained using `truvari version`
    pandas_version = pkg_resources.get_distribution("pandas").version
    tabulate_version = pkg_resources.get_distribution("tabulate").version

    try:
        with open(template_file, "r") as f:
            template_text = f.read()
    except Exception as e:
        print(f"Error reading {template_file}: {e}")
        sys.exit(1)

    filled_text = template_text.format(
        pipeline_name=pipeline_name,
        date_of_run=date_of_run,
        snakemake_version=snakemake_version,
        pipeline_version=pipeline_version,
        truvari_version=truvari_version,
        pandas_version=pandas_version,
        tabulate_version=tabulate_version,
        summary_table=summary_table,
    )

    print("Writing the filled README.md file...")
    try:
        with open(output_file, "w") as f:
            f.write(filled_text)
    except Exception as e:
        print(f"Error writing {output_file}: {e}")
        sys.exit(1)


def main():
    """
    Main function to parse command-line arguments, run the Snakemake pipeline,
    generate a summary table, and complete the README.md file.
    """
    parser = argparse.ArgumentParser(description="Run the Truvari Analysis Pipeline.")
    parser.add_argument(
        "--skip-pipeline",
        action="store_true",
        help="Skip running the Snakemake pipeline.",
    )
    args = parser.parse_args()

    if not args.skip_pipeline:
        run_snakemake_pipeline()

    summary_table = generate_summary_table()
    generate_readme(summary_table)

    print("Finished!")


if __name__ == "__main__":
    main()
