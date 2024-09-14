import os
import time
import pyBigWig
import numpy as np
from collections import defaultdict
import psutil
import matplotlib.pyplot as plt
import seaborn as sns

def print_memory_usage():
    process = psutil.Process()
    print(f"Current memory usage: {process.memory_info().rss / 1024 / 1024:.2f} MB")

class FMIndex:
    def __init__(self, text):
        self.text = text + '$'
        self.sa = self.build_suffix_array()
        self.bwt = self.build_bwt()
        self.occ = self.build_occurrence_matrix()
        self.c = self.build_count_array()

    def build_suffix_array(self):
        return sorted(range(len(self.text)), key=lambda i: self.text[i:])

    def build_bwt(self):
        return ''.join(self.text[(i - 1) % len(self.text)] for i in self.sa)

    def build_occurrence_matrix(self):
        occ = defaultdict(lambda: [0] * (len(self.bwt) + 1))
        for i, char in enumerate(self.bwt):
            for c in occ:
                occ[c][i + 1] = occ[c][i]
            occ[char][i + 1] += 1
        return occ

    def build_count_array(self):
        c = defaultdict(int)
        for char in self.bwt:
            c[char] += 1
        return {char: sum(c[k] for k in c if k < char) for char in c}

    def count(self, pattern):
        top, bottom = 0, len(self.bwt) - 1
        while top <= bottom and pattern:
            char = pattern[-1]
            pattern = pattern[:-1]
            if char not in self.c:
                return 0
            top = self.c[char] + self.occ[char][top]
            bottom = self.c[char] + self.occ[char][bottom + 1] - 1
        return bottom - top + 1

def traditional_search(text, pattern):
    return text.count(pattern)

def process_bigwig(file_path, chunk_size=1000000):
    bw = pyBigWig.open(file_path)
    chroms = bw.chroms()
    all_values = []
    for chrom in chroms:
        for start in range(0, chroms[chrom], chunk_size):
            end = min(start + chunk_size, chroms[chrom])
            values = bw.values(chrom, start, end)
            all_values.extend([v for v in values if v is not None])
    bw.close()
    return all_values

def benchmark(file_path, patterns):
    print(f"Processing file: {file_path}")
    values = process_bigwig(file_path)
    text = ''.join([chr(int(v * 10) + 33) for v in values])  # Convert to string

    start_time = time.time()
    fm_index = FMIndex(text)
    fm_index_build_time = time.time() - start_time

    fm_index_search_time = 0
    for pattern in patterns:
        start_time = time.time()
        fm_index.count(pattern)
        fm_index_search_time += time.time() - start_time

    traditional_search_time = 0
    for pattern in patterns:
        start_time = time.time()
        traditional_search(text, pattern)
        traditional_search_time += time.time() - start_time

    return {
        'File': os.path.basename(file_path),
        'FM-Index Build Time': fm_index_build_time,
        'FM-Index Search Time': fm_index_search_time,
        'Traditional Search Time': traditional_search_time,
        'Values': values
    }

def plot_search_time_comparison(results):
    files = [r['File'] for r in results]
    fm_times = [r['FM-Index Search Time'] for r in results]
    trad_times = [r['Traditional Search Time'] for r in results]

    plt.figure(figsize=(12, 6))
    x = range(len(files))
    plt.bar([i - 0.2 for i in x], fm_times, width=0.4, label='FM-Index Search', color='blue')
    plt.bar([i + 0.2 for i in x], trad_times, width=0.4, label='Traditional Search', color='orange')
    plt.xlabel('Files')
    plt.ylabel('Search Time (seconds)')
    plt.title('Search Time Comparison')
    plt.legend()
    plt.xticks(x, files, rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig('1_search_time_comparison.png')
    plt.close()

def plot_speedup(results):
    files = [r['File'] for r in results]
    speedups = [r['Traditional Search Time'] / r['FM-Index Search Time'] for r in results]

    plt.figure(figsize=(10, 6))
    plt.bar(files, speedups, color='green')
    plt.xlabel('Files')
    plt.ylabel('Speedup Factor')
    plt.title('FM-Index Speedup over Traditional Search')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig('2_speedup.png')
    plt.close()

def plot_build_time(results):
    files = [r['File'] for r in results]
    build_times = [r['FM-Index Build Time'] for r in results]

    plt.figure(figsize=(10, 6))
    plt.bar(files, build_times, color='purple')
    plt.xlabel('Files')
    plt.ylabel('Build Time (seconds)')
    plt.title('FM-Index Build Time')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig('3_build_time.png')
    plt.close()

def plot_value_distribution(results):
    plt.figure(figsize=(12, 6))
    for result in results:
        sns.kdeplot(result['Values'], label=result['File'])
    plt.xlabel('Value')
    plt.ylabel('Density')
    plt.title('Value Distribution Across Files')
    plt.legend()
    plt.tight_layout()
    plt.savefig('4_value_distribution.png')
    plt.close()

def plot_cumulative_time(results):
    files = [r['File'] for r in results]
    build_times = [r['FM-Index Build Time'] for r in results]
    fm_search_times = [r['FM-Index Search Time'] for r in results]
    trad_search_times = [r['Traditional Search Time'] for r in results]

    plt.figure(figsize=(12, 6))
    plt.bar(files, build_times, label='Build Time', color='purple')
    plt.bar(files, fm_search_times, bottom=build_times, label='FM-Index Search Time', color='blue')
    plt.bar(files, trad_search_times, label='Traditional Search Time', color='orange')
    plt.xlabel('Files')
    plt.ylabel('Time (seconds)')
    plt.title('Cumulative Time Comparison')
    plt.legend()
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig('5_cumulative_time.png')
    plt.close()

def plot_memory_usage(memory_usage):
    plt.figure(figsize=(10, 6))
    plt.plot(memory_usage, marker='o')
    plt.xlabel('Measurement Points')
    plt.ylabel('Memory Usage (MB)')
    plt.title('Memory Usage During Processing')
    plt.tight_layout()
    plt.savefig('6_memory_usage.png')
    plt.close()

def plot_search_time_vs_file_size(results):
    file_sizes = [len(r['Values']) for r in results]
    fm_times = [r['FM-Index Search Time'] for r in results]
    trad_times = [r['Traditional Search Time'] for r in results]

    plt.figure(figsize=(10, 6))
    plt.scatter(file_sizes, fm_times, label='FM-Index Search', color='blue')
    plt.scatter(file_sizes, trad_times, label='Traditional Search', color='orange')
    plt.xlabel('File Size (number of values)')
    plt.ylabel('Search Time (seconds)')
    plt.title('Search Time vs File Size')
    plt.legend()
    plt.tight_layout()
    plt.savefig('7_search_time_vs_file_size.png')
    plt.close()

def plot_bwt_example():
    text = "BANANA$"
    rotations = sorted([text[i:] + text[:i] for i in range(len(text))])
    bwt = ''.join([r[-1] for r in rotations])

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 10))
    ax1.table(cellText=rotations, loc='center', cellLoc='center')
    ax1.set_title("Sorted Rotations")
    ax1.axis('off')

    ax2.text(0.5, 0.5, f"BWT: {bwt}", fontsize=16, ha='center')
    ax2.set_title("Burrows-Wheeler Transform")
    ax2.axis('off')

    plt.tight_layout()
    plt.savefig('8_bwt_example.png')
    plt.close()

def plot_fm_index_search_example():
    text = "BANANA$"
    fm_index = FMIndex(text)
    pattern = "ANA"
    
    fig, axs = plt.subplots(len(pattern), 1, figsize=(10, 4*len(pattern)))
    for i, char in enumerate(reversed(pattern)):
        top, bottom = 0, len(fm_index.bwt) - 1
        if i > 0:
            top = fm_index.c[char] + fm_index.occ[char][top]
            bottom = fm_index.c[char] + fm_index.occ[char][bottom + 1] - 1
        
        axs[i].text(0.5, 0.5, f"Step {len(pattern)-i}: Char '{char}', Range: [{top}, {bottom}]", 
                    fontsize=12, ha='center')
        axs[i].axis('off')
    
    plt.tight_layout()
    plt.savefig('9_fm_index_search_example.png')
    plt.close()

def plot_performance_summary(results):
    files = [r['File'] for r in results]
    build_times = [r['FM-Index Build Time'] for r in results]
    fm_search_times = [r['FM-Index Search Time'] for r in results]
    trad_search_times = [r['Traditional Search Time'] for r in results]
    speedups = [t/f for t, f in zip(trad_search_times, fm_search_times)]

    fig, axs = plt.subplots(2, 2, figsize=(15, 12))
    
    axs[0, 0].bar(files, build_times)
    axs[0, 0].set_title('FM-Index Build Time')
    axs[0, 0].set_xticklabels(files, rotation=45, ha='right')
    
    axs[0, 1].bar(files, fm_search_times, label='FM-Index')
    axs[0, 1].bar(files, trad_search_times, bottom=fm_search_times, label='Traditional')
    axs[0, 1].set_title('Search Time Comparison')
    axs[0, 1].legend()
    axs[0, 1].set_xticklabels(files, rotation=45, ha='right')
    
    axs[1, 0].bar(files, speedups)
    axs[1, 0].set_title('Speedup Factor')
    axs[1, 0].set_xticklabels(files, rotation=45, ha='right')
    
    file_sizes = [len(r['Values']) for r in results]
    axs[1, 1].scatter(file_sizes, speedups)
    axs[1, 1].set_title('Speedup vs File Size')
    axs[1, 1].set_xlabel('File Size (number of values)')
    axs[1, 1].set_ylabel('Speedup Factor')
    
    plt.tight_layout()
    plt.savefig('10_performance_summary.png')
    plt.close()

def main():
    base_folder = '/Users/verisimilitude/Documents/GitHub/MERC/data/subset/foldChange'
    patterns = ['AAA', 'CCC', 'GGG', 'TTT', 'ACGT']
    
    bigwig_files = [f for f in os.listdir(base_folder) if f.lower().endswith(('.bigwig', '.bw'))]
    
    results = []
    memory_usage = []
    for file in bigwig_files[:5]:  # Process up to 5 files
        memory_usage.append(psutil.Process().memory_info().rss / 1024 / 1024)
        file_path = os.path.join(base_folder, file)
        result = benchmark(file_path, patterns)
        results.append(result)
        memory_usage.append(psutil.Process().memory_info().rss / 1024 / 1024)

    # Generate plots
    plot_search_time_comparison(results)
    plot_speedup(results)
    plot_build_time(results)
    plot_value_distribution(results)
    plot_cumulative_time(results)
    plot_memory_usage(memory_usage)
    plot_search_time_vs_file_size(results)
    plot_bwt_example()
    plot_fm_index_search_example()
    plot_performance_summary(results)

    # Print results
    print("\nBenchmark Results:")
    for result in results:
        print(f"\nFile: {result['File']}")
        print(f"FM-Index Build Time: {result['FM-Index Build Time']:.6f} seconds")
        print(f"FM-Index Search Time: {result['FM-Index Search Time']:.6f} seconds")
        print(f"Traditional Search Time: {result['Traditional Search Time']:.6f} seconds")
        speedup = result['Traditional Search Time'] / result['FM-Index Search Time']
        print(f"Speedup: {speedup:.2f}x")

if __name__ == "__main__":
    main()