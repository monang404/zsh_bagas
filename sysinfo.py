import platform
import os
import datetime

try:
    import psutil
except ImportError:
    print("Modul 'psutil' belum terinstal. Silakan jalankan: pip install psutil")
    exit(1)

def get_system_info():
    # Mengambil informasi waktu saat ini
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Informasi OS
    os_name = platform.system()
    os_release = platform.release()
    os_version = platform.version()
    architecture = platform.machine()

    # Informasi CPU
    cpu_cores = psutil.cpu_count(logical=False)
    cpu_threads = psutil.cpu_count(logical=True)
    cpu_usage = psutil.cpu_percent(interval=1)

    # Informasi RAM
    ram = psutil.virtual_memory()
    ram_total = round(ram.total / (1024 ** 3), 2)  # Convert to GB
    ram_used = round(ram.used / (1024 ** 3), 2)    # Convert to GB
    ram_percent = ram.percent

    # Format output
    info = f"""========================================
System Information - {now}
========================================
[OS Information]
OS          : {os_name} {os_release} (Version: {os_version})
Architecture: {architecture}

[CPU Information]
Physical Cores: {cpu_cores}
Total Threads : {cpu_threads}
CPU Usage     : {cpu_usage}%

[RAM Information]
Total RAM   : {ram_total} GB
Used RAM    : {ram_used} GB
RAM Usage   : {ram_percent}%
========================================
"""
    return info

def main():
    # Dapatkan informasi
    sys_info = get_system_info()
    
    # Tampilkan ke layar (console)
    print(sys_info)
    
    # Simpan ke dalam log.txt
    log_file = "log.txt"
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(sys_info + "\n")
        print(f"[SUCCESS] Informasi berhasil disimpan ke dalam file: {log_file}")
    except Exception as e:
        print(f"[ERROR] Gagal menyimpan ke log.txt: {e}")

if __name__ == "__main__":
    main()
