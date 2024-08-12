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
plt.show()
