import numpy as np
import pyBigWig

# Step 1: Load the BigWig files with your paths
bw_chip_seq_input = pyBigWig.open(
    "/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906416_UCSD.Adipose_Tissue.Input.STL003.bw"
)
bw_h3k27ac = pyBigWig.open(
    "/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906394_UCSD.Adipose_Tissue.H3K27ac.STL003.bw"
)

# Step 2: Specify the chromosome (example using chr17) and genomic range
chromosome = "chr17"
start = 0
end_chip = bw_chip_seq_input.chroms(chromosome)  # Get the length of chr17 for ChIP-seq
end_h3k27ac = bw_h3k27ac.chroms(chromosome)  # Get the length of chr17 for H3K27ac

# Step 3: Extract signal values from BigWig files
chip_seq_input_signal = np.array(bw_chip_seq_input.values(chromosome, start, end_chip))
h3k27ac_signal = np.array(bw_h3k27ac.values(chromosome, start, end_h3k27ac))

# Step 4: Close the BigWig files after loading
bw_chip_seq_input.close()
bw_h3k27ac.close()

# Step 5: Handle any NaNs (replace -inf values with NaN, if present)
chip_seq_input_signal[chip_seq_input_signal == -np.inf] = np.nan
h3k27ac_signal[h3k27ac_signal == -np.inf] = np.nan

# Step 6: Count missing values (NaNs) in H3K27ac signal
missing_count = np.isnan(h3k27ac_signal).sum()
print(f"Number of missing values in H3K27ac signal: {missing_count}")
