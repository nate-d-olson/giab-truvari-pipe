import pandas as pd
import truvari

df = pd.read_csv("hapdiff_AllTRandHP.tsv", sep='\t')

# If the input.bed didn't have a header and so we couldn't use the `--header` parameter, we need to name columns
df.columns = ['chrom', 'start', 'end', 'tpbase', 'tp', 'fn', 'fp']

# Sum the columns of interest
sums = df[["tpbase", "tp", "fn", "fp"]].sum()

# Calculate precision, recall, and f1 scores based on the sums
precision, recall, f1 = truvari.performance_metrics(sums['tpbase'], sums['tp'], sums['fn'], sums['fp'])

# Create a DataFrame to store the summed metrics
summed_metrics = pd.DataFrame([{'precision': precision, 'recall': recall, 'f1': f1}])

# Display the summed metrics
print(summed_metrics)
