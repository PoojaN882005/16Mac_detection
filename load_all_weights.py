import serial
import time
import os
import glob

SERIAL_PORT = "COM14"
BAUD_RATE = 2000000
WEIGHTS_DIR = "C:\\Users\\Cambidge Qwality\\Desktop\\Zebra_V2\\sv_mem_files\\"

def load_weights_to_sdram():
    print("Scanning for model .mem files...")
    search_path = os.path.join(WEIGHTS_DIR, "model_*.mem")
    mem_files = sorted(glob.glob(search_path))
    
    if not mem_files:
        print(f"ERROR: No model_*.mem files found in {WEIGHTS_DIR}!")
        return

    print(f"Found {len(mem_files)} memory files to load into SDRAM.")
    
    master_payload = bytearray()
    for file_path in mem_files:
        with open(file_path, "r") as f:
            for line in f:
                line = line.strip()
                if line:
                    val = int(line, 16)
                    master_payload.extend(val.to_bytes(2, byteorder='big'))

    total_bytes = len(master_payload)
    print(f"Total compiled weight payload size: {total_bytes} bytes (~{total_bytes / (1024*1024):.2f} MB)")

    try:
        print(f"Opening {SERIAL_PORT} at {BAUD_RATE} baud...")
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2.0)
        ser.setDTR(False)
        ser.setRTS(False)
        time.sleep(2)
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        
        print("Starting bulk weight transfer to SDRAM (Please wait)...")
        start_time = time.time()
        
        chunk_size = 1024
        for i in range(0, total_bytes, chunk_size):
            chunk = master_payload[i:i+chunk_size]
            ser.write(chunk)
            time.sleep(0.0005) 
            
            progress = ((i + len(chunk)) / total_bytes) * 100
            print(f"\rUpload Progress: {progress:.1f}%", end="")

        print(f"\n\nSUCCESS! All weights loaded into SDRAM in {time.time() - start_time:.2f} seconds.")
        
        # Keep port open and wait for user confirmation
        input("\nWeights are fully loaded and FPGA is stabilized. Press [ENTER] to release port and proceed to image inference...")
        
        ser.close()
        print("Port released.")
        
    except Exception as e:
        print(f"\nError during weight transmission: {e}")

if __name__ == "__main__":
    load_weights_to_sdram()