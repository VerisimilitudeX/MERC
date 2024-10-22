import pyBigWig
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import KFold
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

# Step 5: Randomly hide part of the original data in the training set (simulate missing data)
np.random.seed(42)
valid_indices = ~np.isnan(chip_seq_input_signal) & ~np.isnan(h3k27ac_signal)
total_valid_data = np.sum(valid_indices)
holdout_size = int(0.2 * total_valid_data)
holdout_indices = np.random.choice(np.where(valid_indices)[0], size=holdout_size, replace=False)

# Hide these values in the H3K27ac signal (mark as NaN)
h3k27ac_signal[holdout_indices] = np.nan

# Step 6: Remove NaN rows for training (only non-NaN rows for chip_seq and h3k27ac)
valid_train_indices = ~np.isnan(h3k27ac_signal) & ~np.isnan(chip_seq_input_signal)
X_train = chip_seq_input_signal[valid_train_indices].reshape(-1, 1)
y_train = h3k27ac_signal[valid_train_indices]

# Step 7: Initialize Linear Regression model
model = LinearRegression()

# Step 8: Use K-Fold cross-validation (don't randomize the order) to calculate training and validation error
kf = KFold(n_splits=5, shuffle=False)
train_mse_list = []
validation_mse_list = []

for train_index, validation_index in kf.split(X_train):
    X_fold_train, X_fold_validation = X_train[train_index], X_train[validation_index]
    y_fold_train, y_fold_validation = y_train[train_index], y_train[validation_index]
    
    # Train the model on the training fold
    model.fit(X_fold_train, y_fold_train)
    
    # Predict on the training and validation fold
    y_train_pred = model.predict(X_fold_train)
    y_validation_pred = model.predict(X_fold_validation)
    
    # Calculate MSE for training and validation
    train_mse = mean_squared_error(y_fold_train, y_train_pred)
    validation_mse = mean_squared_error(y_fold_validation, y_validation_pred)
    
    # Append results
    train_mse_list.append(train_mse)
    validation_mse_list.append(validation_mse)
    
    # Output current step
    print(f"Fold completed: Training MSE = {train_mse}, Validation MSE = {validation_mse}")

# Step 9: Calculate the mean MSE for training and validation
mean_train_mse = np.mean(train_mse_list)
mean_validation_mse = np.mean(validation_mse_list)

print(f"Mean Training MSE: {mean_train_mse}")
print(f"Mean Validation MSE: {mean_validation_mse}")

# Step 10: Impute the originally missing values in the actual data
imputation_indices = np.isnan(h3k27ac_signal) & ~np.isnan(chip_seq_input_signal)
X_missing = chip_seq_input_signal[imputation_indices].reshape(-1, 1)
predicted_missing_values = model.predict(X_missing)

# Step 11: Assign imputed values to the original missing regions
h3k27ac_signal[imputation_indices] = predicted_missing_values

# Step 12: Report the final test MSE
X_test = chip_seq_input_signal[holdout_indices].reshape(-1, 1)
y_test = original_h3k27ac_signal[holdout_indices]  # The actual values before they were hidden
y_test_pred = model.predict(X_test)
test_mse = mean_squared_error(y_test, y_test_pred)

print(f"Test MSE (overall): {test_mse}")

# mse of higher peaks
threshold = 20
high_signal_indices = y_test > threshold
mse_high_signals = mean_squared_error(y_test[high_signal_indices], y_test_pred[high_signal_indices])
print(f"MSE on peaks > 20: {mse_high_signals}")

# Step 13: Plot comparison between original, imputed, and actual values
plt.figure(figsize=(10, 5))

# Plot original H3K27ac signal (before hiding)
plt.plot(range(len(original_h3k27ac_signal)), original_h3k27ac_signal, label='Original H3K27ac Signal', color='blue', alpha=0.6)

# Highlight the missing (imputed) region in red
plt.plot(holdout_indices, y_test, 'ro', label='Actual Hidden Values', markersize=5)

# Plot imputed values
plt.plot(holdout_indices, y_test_pred, 'go', label='Imputed Values', markersize=5)

plt.title('Comparison of Original, Imputed, and Hidden (Actual) Values')
plt.xlabel('Genomic Position')
plt.ylabel('Signal Intensity')
plt.legend()
plt.show()