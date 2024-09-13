import os
import time
import pyBigWig
import numpy as np
from collections import defaultdict
import psutil
import math

def print_memory_usage():
    process = psutil.Process()
    print(f"Current memory usage: {process.memory_info().rss / 1024 / 1024:.2f} MB")

class SimpleIndex:
    def __init__(self, resolution=0.1):
        self.resolution = resolution
        self.index = defaultdict(list)

    def add_value(self, value, position):
        if value is not None and not math.isnan(value):
            key = int(value / self.resolution)
            self.index[key].append(position)

    def count(self, target):
        key = int(target / self.resolution)
        return len(self.index[key])

def traditional_search(values, target, tolerance):
    return sum(1 for v in values if v is not None and not math.isnan(v) and abs(v - target) <= tolerance)

def process_chromosome(bw, chrom, length, chunk_size=1000000):
    index = SimpleIndex()
    total_values = 0
    for start in range(0, length, chunk_size):
        end = min(start + chunk_size, length)
        chunk = bw.values(chrom, start, end)
        for i, value in enumerate(chunk):
            index.add_value(value, start + i)
            total_values += 1
        print(f"Processed {end}/{length} bases")
        print_memory_usage()
    return index, total_values

def benchmark_chromosome(bw, chrom, length, targets, tolerance):
    print(f"Processing chromosome: {chrom}")
    try:
        index, total_values = process_chromosome(bw, chrom, length)
        
        index_search_time = 0
        for target in targets:
            start_time = time.time()
            index.count(target)
            index_search_time += time.time() - start_time
        
        traditional_search_time = 0
        for target in targets:
            start_time = time.time()
            traditional_search(bw.values(chrom, 0, length), target, tolerance)
            traditional_search_time += time.time() - start_time
        
        return index_search_time, traditional_search_time, total_values
    except Exception as e:
        print(f"Error processing chromosome {chrom}: {str(e)}")
        return 0, 0, 0

def benchmark(file_path, targets, tolerance):
    print(f"\nStarting benchmark for file: {file_path}")
    
    bw = pyBigWig.open(file_path)
    chroms = bw.chroms()
    
    total_index_search_time = 0
    total_traditional_search_time = 0
    total_values = 0
    
    for chrom, length in chroms.items():
        index_time, trad_time, values = benchmark_chromosome(bw, chrom, length, targets, tolerance)
        total_index_search_time += index_time
        total_traditional_search_time += trad_time
        total_values += values
        print(f"Finished processing chromosome {chrom}")
        print_memory_usage()
    
    bw.close()
    
    return {
        'Index Search Time': total_index_search_time,
        'Traditional Search Time': total_traditional_search_time,
        'Total Values': total_values
    }

def main():
    base_folder = '/Users/verisimilitude/Documents/GitHub/MERC/data/subset/foldChange'
    
    print(f"Checking contents of {base_folder}:")
    for item in os.listdir(base_folder):
        print(item)
    
    targets = [0.5, 1.0, 1.5, 2.0, 2.5]  # Example target values
    tolerance = 0.1
    
    bigwig_files = [f for f in os.listdir(base_folder) if f.lower().endswith(('.bigwig', '.bw'))]
    total_files = len(bigwig_files)
    
    print(f"\nFound {total_files} BigWig files to process")
    
    if not bigwig_files:
        print(f"No BigWig files found in {base_folder}")
        return
    
    results = []
    for i, file in enumerate(bigwig_files, 1):
        print(f"\nProcessing file {i}/{total_files}: {file}")
        print_memory_usage()
        file_path = os.path.join(base_folder, file)
        result = benchmark(file_path, targets, tolerance)
        result['File'] = file
        results.append(result)
        print(f"Finished processing file {i}/{total_files}")
        print_memory_usage()
    
    # Print results
    print("\nBenchmark Results:")
    for result in results:
        print(f"\nFile: {result['File']}")
        print(f"Index Search Time: {result['Index Search Time']:.4f} seconds")
        print(f"Traditional Search Time: {result['Traditional Search Time']:.4f} seconds")
        print(f"Total Values: {result['Total Values']}")
        if result['Index Search Time'] > 0:
            speedup = result['Traditional Search Time'] / result['Index Search Time']
            print(f"Speedup: {speedup:.2f}x")
        else:
            print("Speedup: N/A (Index Search Time is 0)")

if __name__ == "__main__":
    main()