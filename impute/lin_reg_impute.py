import matplotlib.pyplot as plt
import numpy as np
import pyBigWig
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.metrics import accuracy_score, mean_squared_error
from sklearn.model_selection import KFold
from sklearn.neighbors import KNeighborsRegressor

bw_chip_seq_input = pyBigWig.open(
    "/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906416_UCSD.Adipose_Tissue.Input.STL003.bw"
)
bw_h3k27ac = pyBigWig.open(
    "/Users/verisimilitude/Documents/GitHub/MERC/data/subset/GSM906394_UCSD.Adipose_Tissue.H3K27ac.STL003.bw"
)

chromosome = "chr17"
start = 0
end_chip = bw_chip_seq_input.chroms(chromosome)
end_h3k27ac = bw_h3k27ac.chroms(chromosome)

chip_seq_input_signal = np.array(bw_chip_seq_input.values(chromosome, start, end_chip))
h3k27ac_signal = np.array(bw_h3k27ac.values(chromosome, start, end_h3k27ac))

chip_seq_input_signal[chip_seq_input_signal == -np.inf] = np.nan
h3k27ac_signal[h3k27ac_signal == -np.inf] = np.nan

bw_chip_seq_input.close()
bw_h3k27ac.close()

original_h3k27ac_signal = np.copy(h3k27ac_signal)

np.random.seed(42)
valid_indices = ~np.isnan(chip_seq_input_signal) & ~np.isnan(h3k27ac_signal)
total_valid_data = np.sum(valid_indices)
holdout_size = int(0.2 * total_valid_data)
holdout_indices = np.random.choice(
    np.where(valid_indices)[0], size=holdout_size, replace=False
)
h3k27ac_signal[holdout_indices] = np.nan

valid_train_indices = ~np.isnan(h3k27ac_signal) & ~np.isnan(chip_seq_input_signal)
X_train = chip_seq_input_signal[valid_train_indices].reshape(-1, 1)
y_train = h3k27ac_signal[valid_train_indices]

# Initialize models
models = {
    "Linear Regression": LinearRegression(),
    "KNN Regression": KNeighborsRegressor(n_neighbors=5),  # You can tune n_neighbors
    "Logistic Regression": LogisticRegression(
        max_iter=1000
    ),  # for binarized prediction
}

# Binarize the target data for logistic regression
threshold = np.median(y_train)
y_train_binary = (y_train > threshold).astype(int)  # Adjust based on data distribution

# Step 8: K-Fold cross-validation
kf = KFold(n_splits=5, shuffle=False)

# Train and validate each model
for model_name, model in models.items():
    print(f"\nTraining {model_name}...")
    train_mse_list = []
    validation_mse_list = []

    for fold, (train_index, validation_index) in enumerate(kf.split(X_train), 1):
        print(f"Starting fold {fold} for {model_name}...")

        X_fold_train, X_fold_validation = (
            X_train[train_index],
            X_train[validation_index],
        )
        y_fold_train = (
            y_train[train_index]
            if model_name != "Logistic Regression"
            else y_train_binary[train_index]
        )
        y_fold_validation = (
            y_train[validation_index]
            if model_name != "Logistic Regression"
            else y_train_binary[validation_index]
        )

        # Train the model on the training fold
        model.fit(X_fold_train, y_fold_train)

        # Predict on the training and validation fold
        y_train_pred = model.predict(X_fold_train)
        y_validation_pred = model.predict(X_fold_validation)

        if model_name == "Logistic Regression":
            # Calculate accuracy for classification
            train_metric = accuracy_score(y_fold_train, y_train_pred)
            validation_metric = accuracy_score(y_fold_validation, y_validation_pred)
        else:
            # Calculate MSE for regression models
            train_metric = mean_squared_error(y_fold_train, y_train_pred)
            validation_metric = mean_squared_error(y_fold_validation, y_validation_pred)

        # Append results
        train_mse_list.append(train_metric)
        validation_mse_list.append(validation_metric)

        print(
            f"{model_name} - Fold {fold} Training {'Accuracy' if model_name == 'Logistic Regression' else 'MSE'} = {train_metric}"
        )
        print(
            f"{model_name} - Fold {fold} Validation {'Accuracy' if model_name == 'Logistic Regression' else 'MSE'} = {validation_metric}"
        )

    # Calculate mean metrics
    mean_train_metric = np.mean(train_mse_list)
    mean_validation_metric = np.mean(validation_mse_list)

    print(
        f"{model_name} - Mean Training {'Accuracy' if model_name == 'Logistic Regression' else 'MSE'}: {mean_train_metric}"
    )
    print(
        f"{model_name} - Mean Validation {'Accuracy' if model_name == 'Logistic Regression' else 'MSE'}: {mean_validation_metric}"
    )

# Step 10: Impute missing values using Linear Regression model
imputation_indices = np.isnan(h3k27ac_signal) & ~np.isnan(chip_seq_input_signal)
X_missing = chip_seq_input_signal[imputation_indices].reshape(-1, 1)
predicted_missing_values = models["Linear Regression"].predict(X_missing)
h3k27ac_signal[imputation_indices] = predicted_missing_values

# Plotting code remains the same
plt.figure(figsize=(10, 5))

# Plot original H3K27ac signal (before hiding)
plt.plot(
    range(len(original_h3k27ac_signal)),
    original_h3k27ac_signal,
    label="Original H3K27ac Signal",
    color="blue",
    alpha=0.6,
)

# Highlight the missing (imputed) region in red
plt.plot(
    holdout_indices,
    original_h3k27ac_signal[holdout_indices],
    "ro",
    label="Actual Hidden Values",
    markersize=5,
)

# Plot imputed values
plt.plot(
    holdout_indices,
    h3k27ac_signal[holdout_indices],
    "go",
    label="Imputed Values",
    markersize=5,
)

plt.title("Comparison of Original, Imputed, and Hidden (Actual) Values")
plt.xlabel("Genomic Position")
plt.ylabel("Signal Intensity")
plt.legend()
plt.show()
