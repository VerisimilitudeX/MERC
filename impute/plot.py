import pyBigWig
import numpy as np
import matplotlib.pyplot as plt

# Load the BigWig files with your paths
bw_chip_seq_input = pyBigWig.open('/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906416_UCSD.Adipose_Tissue.Input.STL003.bw')
bw_h3k27ac = pyBigWig.open('/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906394_UCSD.Adipose_Tissue.H3K27ac.STL003.bw')

# Specify the chromosome and genomic range
chromosome = "chr17"
start = 0
end_chip = bw_chip_seq_input.chroms(chromosome)  # Get the length of chr17 for ChIP-seq
end_h3k27ac = bw_h3k27ac.chroms(chromosome)  # Get the length of chr17 for H3K27ac

# Extract the actual signal values from BigWig files
chip_seq_input_signal = np.array(bw_chip_seq_input.values(chromosome, start, end_chip))
h3k27ac_signal = np.array(bw_h3k27ac.values(chromosome, start, end_h3k27ac))

# Handle missing values (-inf to NaN)
chip_seq_input_signal[chip_seq_input_signal == -np.inf] = np.nan
h3k27ac_signal[h3k27ac_signal == -np.inf] = np.nan

# Close the BigWig files after use
bw_chip_seq_input.close()
bw_h3k27ac.close()

# Create a plot to visualize the H3K27ac signal with missing data
plt.figure(figsize=(10, 5))
plt.plot(h3k27ac_signal, color='green', label='H3K27ac Signal')

# Amplify the missing data visualization
plt.fill_between(range(len(h3k27ac_signal)), np.nanmin(h3k27ac_signal), np.nanmax(h3k27ac_signal),
                 where=np.isnan(h3k27ac_signal), color='red', alpha=0.5, label='Missing Data')

plt.title('H3K27ac Signal with Missing Values (chr17)')
plt.xlabel('Genomic Position')
plt.ylabel('Signal Intensity')
plt.legend()
plt.show()