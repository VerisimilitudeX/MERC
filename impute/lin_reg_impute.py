import pyBigWig
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
from sklearn.utils import shuffle
import matplotlib.pyplot as plt
import seaborn as sns

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

# Step 5: Visualize the data distribution
plt.figure(figsize=(14, 6))

# Distribution of ChIP-seq input signal
plt.subplot(1, 2, 1)
sns.histplot(chip_seq_input_signal[~np.isnan(chip_seq_input_signal)], kde=True, bins=50, color='blue')
plt.title('ChIP-seq Input Signal Distribution')
plt.xlabel('ChIP-seq Input Signal')

# Distribution of H3K27ac signal
plt.subplot(1, 2, 2)
sns.histplot(h3k27ac_signal[~np.isnan(h3k27ac_signal)], kde=True, bins=50, color='green')
plt.title('H3K27ac Signal Distribution')
plt.xlabel('H3K27ac Signal')

plt.tight_layout()
plt.show()

# Scatter plot of ChIP-seq input signal vs H3K27ac signal
valid_data_indices = ~np.isnan(chip_seq_input_signal) & ~np.isnan(h3k27ac_signal)
plt.figure(figsize=(6, 6))
plt.scatter(chip_seq_input_signal[valid_data_indices], h3k27ac_signal[valid_data_indices], alpha=0.5, color='purple')
plt.title('ChIP-seq Input vs H3K27ac Signal')
plt.xlabel('ChIP-seq Input Signal')
plt.ylabel('H3K27ac Signal')
plt.show()

# Step 6: Shuffle and re-split the data into training, validation, and test sets
# Only use valid data (non-NaN values)
chip_seq_input_signal_shuffled, h3k27ac_signal_shuffled = shuffle(
    chip_seq_input_signal[valid_data_indices], h3k27ac_signal[valid_data_indices], random_state=42
)

# Step 7: Split the data into 60% training, 20% validation, 20% test
n = len(chip_seq_input_signal_shuffled)
train_size = int(0.6 * n)
validation_size = int(0.2 * n)

X_train = chip_seq_input_signal_shuffled[:train_size].reshape(-1, 1)
y_train = h3k27ac_signal_shuffled[:train_size]

X_validation = chip_seq_input_signal_shuffled[train_size:train_size + validation_size].reshape(-1, 1)
y_validation = h3k27ac_signal_shuffled[train_size:train_size + validation_size]

X_test = chip_seq_input_signal_shuffled[train_size + validation_size:].reshape(-1, 1)
y_test = h3k27ac_signal_shuffled[train_size + validation_size:]

# Step 8: Train a Linear Regression model on the shuffled training data
model = LinearRegression()
model.fit(X_train, y_train)

# Step 9: Predict and calculate the MSE for training, validation, and test sets
y_train_pred = model.predict(X_train)
y_validation_pred = model.predict(X_validation)
y_test_pred = model.predict(X_test)

train_mse = mean_squared_error(y_train, y_train_pred)
validation_mse = mean_squared_error(y_validation, y_validation_pred)
test_mse = mean_squared_error(y_test, y_test_pred)

print(f"Training MSE: {train_mse}")
print(f"Validation MSE: {validation_mse}")
print(f"Test MSE: {test_mse}")

# Step 10: Impute the originally missing values in the actual data
imputation_indices = np.isnan(h3k27ac_signal) & ~np.isnan(chip_seq_input_signal)
X_missing = chip_seq_input_signal[imputation_indices].reshape(-1, 1)
predicted_missing_values = model.predict(X_missing)

# Step 11: Assign imputed values to the original missing regions
h3k27ac_signal[imputation_indices] = predicted_missing_values

# Step 12: Plot the imputed regions in the original data
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

print(f"Training, validation, and test MSE calculated. Showing region {zoom_start} to {zoom_end}.")