import pandas as pd
import numpy as np
from pyBigWig import open as open_bw

# Load the bigwig file
bigwig_file = 'your_file.bw'  # Replace with the actual path to your BigWig file
bw = open_bw(bigwig_file)

# Extract data from the bigwig file
chroms = bw.chroms()
data = {chrom: bw.values(chrom, 0, bw.chroms()[chrom]) for chrom in chroms}

# Convert to a pandas DataFrame
df = pd.DataFrame(data)
print(df.head())