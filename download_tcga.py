from huggingface_hub import hf_hub_download, list_repo_files
import os

# Repository ID on Hugging Face
repo_id = "Lab-Rasool/TCGA"

# Your Hugging Face access token
hf_token = "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"  # Replace this with your Hugging Face token if needed

# Directory to download files on the external SSD
download_dir = "/Volumes/T9/tcga"

# Ensure the target download directory exists
os.makedirs(download_dir, exist_ok=True)

# List of folder paths based on the repository structure
files_to_download = [
    "Clinical Data (biobert)/clinical_data.parquet",
    "Clinical Data (gatortorn-base)/clinical_data.parquet",
    "Molecular (SeNMo)/molecular_data.parquet",
    "Pathology Report (gatortorn-base)/pathology_report.parquet",
    "Radiology (REMEDIS)/radiology_data.parquet",
    "Radiology (RadImageNet)/radiology_data.parquet",
    "Slide Image (UNI)/slide_image_data.parquet"
]

# Loop through each file path and download to the specified directory
for file_path in files_to_download:
    try:
        local_path = hf_hub_download(
            repo_id=repo_id,
            filename=file_path,
            local_dir=download_dir,  # Download location on external SSD
            token=hf_token           # Authentication token if the repo is private
        )
        print(f"Downloaded {file_path} to {local_path}")
    except Exception as e:
        print(f"Failed to download {file_path}: {e}")