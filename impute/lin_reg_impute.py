import pyBigWig
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
import matplotlib.pyplot as plt

# Step 1: Load the BigWig files with your paths
bw_chip_seq_input = pyBigWig.open('/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906416_UCSD.Adipose_Tissue.Input.STL003.bw')
bw_h3k27ac = pyBigWig.open('/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906394_UCSD.Adipose_Tissue.H3K27ac.STL003.bw')

# Step 2: Specify the chromosome and genomic range
chromosome = "chr17"
start = 0
end_chip = bw_chip_seq_input.chroms(chromosome)  # Get the length of chr17 for ChIP-seq
end_h3k27ac = bw_h3k27ac.chroms(chromosome)  # Get the length of chr17 for H3K27ac

# Step 3: Extract signal values from BigWig files
chip_seq_input_signal = np.array(bw_chip_seq_input.values(chromosome, start, end_chip))
h3k27ac_signal = np.array(bw_h3k27ac.values(chromosome, start, end_h3k27ac))

# Handle missing values (-inf to NaN)
chip_seq_input_signal[chip_seq_input_signal == -np.inf] = np.nan
h3k27ac_signal[h3k27ac_signal == -np.inf] = np.nan

# Step 4: Close the BigWig files after loading
bw_chip_seq_input.close()
bw_h3k27ac.close()

# Save original H3K27ac signal for comparison
original_h3k27ac_signal = np.copy(h3k27ac_signal)

# Step 5: Identify missing values in H3K27ac and valid ChIP-seq input values
missing_indices = np.isnan(h3k27ac_signal)
valid_chip_seq_indices = ~np.isnan(chip_seq_input_signal)

# Select regions with valid ChIP-seq input but missing H3K27ac data
imputation_indices = missing_indices & valid_chip_seq_indices

# Step 6: Create a holdout set by randomly hiding part of the original data (20% of the data)
np.random.seed(42)  # For reproducibility
total_valid_data = np.sum(valid_chip_seq_indices)
holdout_size = int(0.2 * total_valid_data)
holdout_indices = np.random.choice(np.where(valid_chip_seq_indices)[0], size=holdout_size, replace=False)

# Hide these values in the H3K27ac signal (mark as NaN)
h3k27ac_signal[holdout_indices] = np.nan

# Step 7: Remove rows where ChIP-seq input signal (X_train) has NaN values
valid_train_indices = ~np.isnan(h3k27ac_signal) & valid_chip_seq_indices
X_train = chip_seq_input_signal[valid_train_indices].reshape(-1, 1)
y_train = h3k27ac_signal[valid_train_indices]

# Ensure no NaN values in y_train
assert not np.isnan(y_train).any(), "Training target contains NaN values."

# Step 8: Train a Linear Regression model on the training data (non-hidden regions)
model = LinearRegression()
model.fit(X_train, y_train)

# Step 9: Predict the holdout values
X_holdout = chip_seq_input_signal[holdout_indices].reshape(-1, 1)
predicted_holdout_values = model.predict(X_holdout)

# Step 10: Calculate MSE on the holdout set
original_holdout_values = original_h3k27ac_signal[holdout_indices]
mse = mean_squared_error(original_holdout_values, predicted_holdout_values)
print(f"Mean Squared Error (MSE) for selectively hidden regions: {mse}")

# Step 11: Impute the originally missing values in the actual data
X_missing = chip_seq_input_signal[imputation_indices].reshape(-1, 1)
predicted_missing_values = model.predict(X_missing)

# Step 12: Assign imputed values to the original missing regions
h3k27ac_signal[imputation_indices] = predicted_missing_values

# Step 13: Plot the imputed regions in the original data
imputed_region_indices = np.where(imputation_indices)[0]
first_imputed_index = imputed_region_indices[0]
zoom_start = max(first_imputed_index - 50, 0)
zoom_end = first_imputed_index + 50

# Plot the imputed missing regions
plt.figure(figsize=(10, 5))
plt.plot(range(zoom_start, zoom_end), original_h3k27ac_signal[zoom_start:zoom_end], color='red', alpha=0.7, label='Original H3K27ac Signal (with missing values)')
plt.fill_between(range(zoom_start, zoom_end), 0, original_h3k27ac_signal[zoom_start:zoom_end], 
                 where=np.isnan(original_h3k27ac_signal[zoom_start:zoom_end]), 
                 color='red', alpha=0.3, label='Missing Data')
plt.plot(range(zoom_start, zoom_end), h3k27ac_signal[zoom_start:zoom_end], color='green', linestyle='--', label='Imputed H3K27ac Signal')
plt.title(f'Zoomed In: Imputed Region in H3K27ac Signal (chr17: {zoom_start}-{zoom_end})')
plt.xlabel('Genomic Position')
plt.ylabel('Signal Intensity')
plt.legend()
plt.show()

print(f"Imputation complete. Showing region {zoom_start} to {zoom_end}.")