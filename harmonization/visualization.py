import matplotlib.pyplot as plt
import numpy as np
import pyBigWig
import seaborn as sns

# Load your data (example paths used here)
bw_chip_seq_input = pyBigWig.open(
    "/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906416_UCSD.Adipose_Tissue.Input.STL003.bw"
)
bw_h3k27ac = pyBigWig.open(
    "/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906394_UCSD.Adipose_Tissue.H3K27ac.STL003.bw"
)

# Specify chromosome and range
chromosome = "chr17"
start = 0
end_chip = bw_chip_seq_input.chroms(chromosome)
end_h3k27ac = bw_h3k27ac.chroms(chromosome)

# Extract signal values from BigWig files
chip_seq_input_signal = np.array(bw_chip_seq_input.values(chromosome, start, end_chip))
h3k27ac_signal = np.array(bw_h3k27ac.values(chromosome, start, end_h3k27ac))

# Handle missing values (-inf to NaN)
chip_seq_input_signal[chip_seq_input_signal == -np.inf] = np.nan
h3k27ac_signal[h3k27ac_signal == -np.inf] = np.nan

# Close BigWig files
bw_chip_seq_input.close()
bw_h3k27ac.close()

# Visualize distributions
plt.figure(figsize=(12, 6))
sns.histplot(
    chip_seq_input_signal, bins=50, color="blue", label="ChIP-seq Input", kde=True
)
sns.histplot(h3k27ac_signal, bins=50, color="orange", label="H3K27ac", kde=True)
plt.legend()
plt.title("Distribution of Signal Intensities")
plt.xlabel("Signal Intensity")
plt.ylabel("Frequency")
plt.show()
