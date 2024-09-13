import os
import pyBigWig
import matplotlib.pyplot as plt

# Function to process and plot data from a single BigWig file
def plot_bigwig(file_path):
    try:
        print(f"Processing file: {file_path}")

        # Open the BigWig file
        bw = pyBigWig.open(file_path)

        # Get the list of chromosomes
        chroms = bw.chroms()

        # Plot data for each chromosome
        for chrom in chroms:
            chrom_length = chroms[chrom]
            print(f"Processing chromosome: {chrom}, length: {chrom_length}")

            # Fetch values for the entire chromosome
            values = bw.values(chrom, 0, chrom_length)

            # Check if all values are zero
            non_zero_values = [v for v in values if v != 0]
            if not non_zero_values:
                print(f"No non-zero values found for chromosome {chrom}")
                continue

            print(f"Non-zero values found for chromosome {chrom}!")
            print(f"First 100 non-zero values: {[f'{v:.10f}' for v in non_zero_values[:100]]}")
            print(f"Min non-zero value: {min(non_zero_values):.10f}, Max non-zero value: {max(non_zero_values):.10f}")

            # Plot the data
            plt.figure(figsize=(20, 6))
            plt.plot(range(chrom_length), values, label=f'{chrom}')
            plt.xlabel('Position')
            plt.ylabel('Signal')
            plt.title(f'BigWig Data Visualization: {os.path.basename(file_path)} - {chrom}')
            plt.legend()
            plt.show()

        # Close the BigWig file
        bw.close()

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

# Function to process all BigWig files in a directory
def process_all_bigwig_files(base_folder):
    for root, dirs, files in os.walk(base_folder):
        for file in files:
            if file.endswith(".bigwig") or file.endswith(".bw"):  # Ensure you only process BigWig files
                file_path = os.path.join(root, file)
                plot_bigwig(file_path)

# Example usage: Define your base folder
base_folder = '/Users/verisimilitude/Documents/GitHub/MERC/data/subset'  # Path to your folder with BigWig files

# Process all BigWig files in the specified folder and plot
process_all_bigwig_files(base_folder)