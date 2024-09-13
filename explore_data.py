import pyBigWig
import matplotlib.pyplot as plt

# Function to plot data from a BigWig file
def plot_bigwig(file_path, chrom, start, end):
    try:
        # Open the BigWig file
        bw = pyBigWig.open(file_path)
        
        # Fetch values for the specified region
        values = bw.values(chrom, start, end)
        
        # Close the file
        bw.close()
        
        # Check the range of values to debug
        print(f"Min value: {min(values)}, Max value: {max(values)}")

        # Plot the data
        plt.figure(figsize=(10, 4))
        plt.plot(range(start, end), values, label=f'{chrom}:{start}-{end}')
        
        # Adjusting y-axis range based on the data
        plt.ylim(min(values) - 0.1, max(values) + 0.1)  # Provide a buffer to zoom in on the y-axis
        
        plt.xlabel('Position')
        plt.ylabel('Signal')
        plt.title('BigWig Data Visualization')
        plt.legend()
        plt.show()
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

# Example usage
file_path = '/Users/verisimilitude/Documents/GitHub/MERC/data/subset/foldChange/E005-H3K27ac.fc.signal.bigwig'  # Path to your BigWig file
chrom = 'chr2'  # Chromosome
start = 0  # Start position
end = 10000  # End position

plot_bigwig(file_path, chrom, start, end)