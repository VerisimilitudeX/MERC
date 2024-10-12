import os
import pyBigWig
import numpy as np
import matplotlib.pyplot as plt

def plot_bigwig(file_path):
    try:
        print(f"Processing file: {file_path}")

        # Open the BigWig file
        bw = pyBigWig.open(file_path)

        # Get the list of chromosomes
        chroms = bw.chroms()

        for chrom in chroms:
            chrom_length = chroms[chrom]
            print(f"Processing chromosome: {chrom}, length: {chrom_length}")

            # Fetch values for the entire chromosome in chunks to identify missing data
            chunk_size = 1000000  # Size of chunks to process
            missing_data_found = False
            start_positions = []  # To store start positions of missing data

            for start in range(0, chrom_length, chunk_size):
                end = min(start + chunk_size, chrom_length)
                values = np.array(bw.values(chrom, start, end, numpy=True))

                # Check if there are missing values (NaNs) in the chunk
                if np.isnan(values).any():
                    print(f"Missing data found in chromosome {chrom} at chunk {start}-{end}")
                    start_positions.append((start, end))

            # Check if missing data is not only at the ends
            if start_positions:
                # Get the start and end of the first and last missing chunks
                first_missing_start, first_missing_end = start_positions[0]
                last_missing_start, last_missing_end = start_positions[-1]

                # Check for missing data in the middle (not just at the beginning or end)
                if first_missing_start > 0 and last_missing_end < chrom_length:
                    print(f"Missing data detected in the middle of chromosome {chrom}, plotting data...")

                    # Fetch entire chromosome data to visualize
                    values = np.array(bw.values(chrom, 0, chrom_length, numpy=True))
                    plt.figure(figsize=(20, 6))
                    plt.plot(range(chrom_length), values, label=f'{chrom}', color='blue')

                    # Highlight missing data regions
                    for start, end in start_positions:
                        plt.axvspan(start, end, color='red', alpha=0.5, label='Missing Data Region' if start == first_missing_start else "")

                    plt.xlabel('Position')
                    plt.ylabel('Signal')
                    plt.title(f'BigWig Data Visualization: {os.path.basename(file_path)} - {chrom}')
                    plt.legend(loc='upper right')
                    plt.show()
                else:
                    print(f"Missing data only at the beginning or end of chromosome {chrom}, skipping...")

            else:
                print(f"No missing data found in chromosome {chrom}")

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