import os
import pyBigWig
import numpy as np
from sklearn.impute import SimpleImputer
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error

def read_bigwig(file_path, chrom, start, end):
    """Read values from a BigWig file."""
    with pyBigWig.open(file_path) as bw:
        return np.array(bw.values(chrom, start, end))

def load_dataset(directory, chrom, start, end):
    """Load data from all BigWig files in a directory."""
    data = []
    for filename in os.listdir(directory):
        if filename.endswith(".bigwig"):
            file_path = os.path.join(directory, filename)
            values = read_bigwig(file_path, chrom, start, end)
            data.append(values)
    return np.array(data).T  # Transpose to have features as columns

# Specify the directory, chromosome, and range
directory = '/workspaces/merc/data/subset/pval/'
chrom = 'chr1'
start, end = 0, 1000

# Load the dataset
data = load_dataset(directory, chrom, start, end)

# Impute missing values using mean strategy
imputer = SimpleImputer(strategy='mean')
data_imputed = imputer.fit_transform(data)

# Split data into features and target
X = data_imputed[:, :-1]  # Features
y = data_imputed[:, -1]   # Target

# Split into training and testing sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train a Random Forest Regressor
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Predict and evaluate the model
y_pred = model.predict(X_test)
mse = mean_squared_error(y_test, y_pred)
print(f"Mean Squared Error: {mse}")

# Example of imputing missing values in new data
# Ensure new_data has the same number of features as the original dataset
new_data = np.random.rand(10, data.shape[1])  # Adjusted to match the original feature count
new_data[np.random.choice([True, False], size=new_data.shape)] = np.nan
new_data_imputed = imputer.transform(new_data)

print("Imputed new data:")
print(new_data_imputed)

import matplotlib
matplotlib.use('Agg')  # Use a non-interactive backend
import matplotlib.pyplot as plt

# Visualize imputed data
plt.figure(figsize=(12, 6))
for i, row in enumerate(new_data_imputed):
    plt.plot(row, label=f'Sample {i+1}')

plt.xlabel('Feature Index')
plt.ylabel('Imputed Signal Intensity')
plt.title('Imputed Epigenetic Data')
plt.legend()
plt.grid(True)

# Save the plot to a file
plt.savefig('imputed_data_plot.png')
