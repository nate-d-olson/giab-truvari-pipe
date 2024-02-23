import joblib
import seaborn as sb
import matplotlib.pyplot as plt


data = joblib.load("bench_results/hapdiff_R9_phased_refine.jl")

# Convert 'svtype' and 'szbin' to category if not already
data['svtype'] = data['svtype'].astype('category')
data['szbin'] = data['szbin'].astype('category')

# Set up the matplotlib figure with a specific size
fig, axes = plt.subplots(2, 2, figsize=(20, 16))
axes = axes.flatten()  # Flatten the 2x2 grid into a linear array for easy indexing


for index, state in enumerate(["tpbase", "tp", "fp", "fn"]):
    # Filter the data for the current state
    dat = data[data["state"] == state].copy()

    # Remove unused categories for this subset
    dat['svtype'] = dat['svtype'].cat.remove_unused_categories()
    dat['szbin'] = dat['szbin'].cat.remove_unused_categories()

    p = sb.countplot(data=dat, x="szbin", hue="svtype", ax=axes[index])
    p.set_xticklabels(p.get_xticklabels(), rotation=45, ha='right')
    p.set(title=f"{state} by svtype and szbin")

# Adjust layout for a cleaner look
plt.tight_layout()

# Save the figure containing all subplots
plt.savefig("bench_results/hapdiff_R9_phased_combined.png")
