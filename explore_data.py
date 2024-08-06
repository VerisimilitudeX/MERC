import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def read_wig(file_path):
    with open(file_path, 'r') as file:
        data = []
        chrom = None
        start = None
        step = None
        for line in file:
            if line.startswith('track'):
                continue
            elif line.startswith('fixedStep'):
                parts = line.strip().split()
                chrom = parts[1].split('=')[1]
                start = int(parts[2].split('=')[1])
                step = int(parts[3].split('=')[1])
                position = start
            else:
                try:
                    value = float(line.strip())
                    data.append((chrom, position, value))
                    position += step
                except ValueError:
                    print(f"Skipping line: {line.strip()}")
    return pd.DataFrame(data, columns=['chrom', 'position', 'value'])

# Read the .wig file
file_path = "/Users/verisimilitude/Downloads/GSM1120305_UCSD.Adipose_Tissue.mRNA-Seq.STL002.wig"
wig_data = read_wig(file_path)

# Display basic information
print(wig_data.info())
print("\nFirst few rows:")
print(wig_data.head())

# Basic statistics
print("\nBasic statistics:")
print(wig_data['value'].describe())

# Plot distribution of values
plt.figure(figsize=(10, 6))
sns.histplot(wig_data['value'], kde=True)
plt.title('Distribution of Values')
plt.xlabel('Value')
plt.ylabel('Frequency')
plt.savefig('value_distribution.png')
plt.close()

# Plot values along the chromosome
plt.figure(figsize=(15, 6))
plt.plot(wig_data['position'], wig_data['value'])
plt.title(f'Values along {wig_data["chrom"].iloc[0]}')
plt.xlabel('Position')
plt.ylabel('Value')
plt.savefig('values_along_chromosome.png')
plt.close()

# Identify regions with high values
high_value_threshold = wig_data['value'].quantile(0.99)
high_value_regions = wig_data[wig_data['value'] > high_value_threshold]
print(f"\nRegions with values above the 99th percentile ({high_value_threshold:.2f}):")
print(high_value_regions)

# Save processed data to CSV
wig_data.to_csv('processed_wig_data.csv', index=False)
print("\nProcessed data saved to 'processed_wig_data.csv'")