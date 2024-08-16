from Bio import SeqIO
from Bio.Seq import Seq
from sklearn.preprocessing import StandardScaler
import numpy as np

def preprocess_dna(sequences):
    processed_sequences = []
    for seq in sequences:
        cleaned_seq = ''.join(filter(lambda x: x in 'ATCG', seq.upper()))
        processed_sequences.append(cleaned_seq)
    return processed_sequences


def dna_to_numeric(sequences):
    mapping = {'A': 0, 'T': 1, 'C': 2, 'G': 3}
    numeric_data = []
    for seq in sequences:
        numeric_seq = [mapping[base] for base in seq]
        numeric_data.append(numeric_seq)
    return np.array(numeric_data)


def normalize_data(numeric_data):
    scaler = StandardScaler()
    normalized_data = scaler.fit_transform(numeric_data)
    return normalized_data

dna_sequences = [
    "ATCGATCGATCG",
    "GCTAGCTAGCTA",
    "TTTTAAAACCCC",
    "GGGGCCCCAAAA"
]

processed_sequences = preprocess_dna(dna_sequences)

numeric_data = dna_to_numeric(processed_sequences)

normalized_data = normalize_data(numeric_data)

print("Processed sequences:")
for seq in processed_sequences:
    print(seq)

print("\nNumerical representation:")
print(numeric_data)

print("\nNormalized data:")
print(normalized_data)