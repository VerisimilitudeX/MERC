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
        
        # Plot the data
        plt.figure(figsize=(10, 4))
        plt.plot(range(start, end), values, label=f'{chrom}:{start}-{end}')
        plt.xlabel('Position')
        plt.ylabel('Signal')
        plt.title('BigWig Data Visualization')
        plt.legend()
        plt.show()
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

# Example usage
file_path = 'E001-H3K4me1.fc.signal.bigwig'  # Path to your BigWig file
chrom = 'chr1'  # Chromosome
start = 0  # Start position
end = 10000  # End position

plot_bigwig(file_path, chrom, start, end)
