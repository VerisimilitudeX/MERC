import os
import pyBigWig
import numpy as np
import matplotlib.pyplot as plt
from itertools import groupby
from operator import itemgetter

def plot_bigwig(file_path):
    try:
        print(f"Processing file: {file_path}")

        # Open the BigWig file
        bw = pyBigWig.open(file_path)

        # Get the list of chromosomes
        chroms = bw.chroms()

        for chrom in chroms:
            total_chrom_length = bw.chroms()[chrom]
            print(f"Processing chromosome: {chrom}, total length: {total_chrom_length}")

            # Get all intervals with data
            intervals = bw.intervals(chrom)
            if not intervals:
                print(f"No data intervals in chromosome {chrom}, skipping...")
                continue

            # Check if the chromosome has full coverage or no missing data possible
            total_covered_positions = sum(interval[1] - interval[0] for interval in intervals)
            if total_covered_positions == total_chrom_length:
                print(f"Chromosome {chrom} has full coverage, skipping...")
                continue

            # Process only specific regions (intervals) rather than the whole chromosome
            for interval in intervals:
                start, end, _ = interval
                interval_length = end - start
                # Fetch values for this interval
                values = bw.values(chrom, start, end, numpy=True)
                # Check for missing data in this interval
                missing_data = np.isnan(values)
                num_missing = np.sum(missing_data)
                if num_missing == 0:
                    continue  # Skip intervals without missing data

                # Create an array of positions for the interval
                positions = np.arange(start, end)

                # Mask the missing data
                masked_values = np.ma.array(values, mask=missing_data)

                # Plot the data for the interval with missing data
                plt.figure(figsize=(20, 6))
                plt.plot(positions, masked_values, color='blue', label='Data', linewidth=0.5)

                # Highlight missing data regions
                missing_indices = np.where(missing_data)[0]
                if len(missing_indices) > 0:
                    missing_label_added = False
                    for k, g in groupby(enumerate(missing_indices), lambda ix: ix[0] - ix[1]):
                        group = list(map(itemgetter(1), g))
                        start = group[0] + interval[0]
                        end = group[-1] + interval[0]
                        if not missing_label_added:
                            plt.axvspan(start, end, color='red', alpha=0.5, label='Missing Data Region')
                            missing_label_added = True
                        else:
                            plt.axvspan(start, end, color='red', alpha=0.5)

                plt.xlabel('Position')
                plt.ylabel('Signal')
                plt.title(f'BigWig Data Visualization: {os.path.basename(file_path)} - {chrom}')
                plt.legend(loc='upper right')
                plt.tight_layout()
                plt.show()

        # Close the BigWig file
        bw.close()

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def process_all_bigwig_files(base_folder):
    for root, dirs, files in os.walk(base_folder):
        for file in files:
            if file.endswith(".bigwig") or file.endswith(".bw"):
                file_path = os.path.join(root, file)
                plot_bigwig(file_path)

# Example usage: Define your base folder
base_folder = '/Users/verisimilitude/Documents/GitHub/MERC/data/subset/foldChange'  # Update with your actual path

# Process all BigWig files in the specified folder and plot
process_all_bigwig_files(base_folder)