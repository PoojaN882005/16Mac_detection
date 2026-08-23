import serial
import cv2
import numpy as np
import os
import sys
import time

SERIAL_PORT = "COM14"
BAUD_RATE = 2000000
IMG_SIZE = 320
OUT_DIR = "C:\\Users\\Cambidge Qwality\\Desktop\\Zebra_V2\\output_results\\"

REQ_MAGIC = bytes([0xA5, 0x5A])
RSP_MAGIC = bytes([0x5A, 0xA5])

def run_zebra_detection():
    # Ensure the output directory exists
    os.makedirs(OUT_DIR, exist_ok=True)
    image_path = r"C:\Users\Cambidge Qwality\Desktop\New folder\IMAGE_TEST\Test (90).jpg"
    
    print(f"Loading image from: {image_path}")
    img = cv2.imread(image_path)
    if img is None:
        print("ERROR: Could not load source image. Check the file path.")
        return
        
    img = cv2.resize(img, (IMG_SIZE, IMG_SIZE))
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # Flatten the entire image into a single 1D byte array for bulk transfer
    full_image_payload = img_rgb.flatten().tobytes()
    total_bytes = len(full_image_payload)
    print(f"Image flattened. Total payload: {total_bytes} bytes.")
    
    try:
        print(f"Opening {SERIAL_PORT} at {BAUD_RATE} baud...")
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2.0)
        ser.setDTR(False)
        ser.setRTS(False)
        time.sleep(2.0) 
        
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        print("Hardware link open. Blasting full image to FPGA...\n")
        
        start_time = time.time()
        
        # Send sync magic followed immediately by the entire image chunks
        ser.write(REQ_MAGIC)
        
        chunk_size = 4096
        for i in range(0, total_bytes, chunk_size):
            chunk = full_image_payload[i:i+chunk_size]
            ser.write(chunk)
            time.sleep(0.0005) # Tiny breather for the hardware FIFO
            
            percent = ((i + len(chunk)) / total_bytes) * 100
            sys.stdout.write(f"\rUpload Progress: [{percent:.1f}%]")
            sys.stdout.flush()

        print("\n\nImage transfer complete. FPGA is now batch-processing all layers. Waiting for response...")
        
        # Wait for FPGA response sync (5A A5) indicating all layers are done
        window = bytearray()
        deadline = time.time() + 15.0 
        synced = False
        while time.time() < deadline:
            b = ser.read(1)
            if not b: continue
            window += b
            if len(window) > 2:
                del window[0]
            if bytes(window) == RSP_MAGIC:
                synced = True
                break
        
        if not synced:
            raise TimeoutError("FPGA did not complete processing. Sync lock lost.")
        
        print(f"SUCCESS! FPGA completed multi-layer inference in {time.time() - start_time:.2f} seconds.")
        
        # Read the resulting bounding box coordinates (1024 bytes for a 32x32 feature map)
        expected_output_bytes = 1024 
        result_bytes = ser.read(expected_output_bytes)
        print("Output bytes received successfully. Rendering bounding boxes on screen...")
        
        # --- ACTUAL OPENCV DRAWING CODE ---
        # Reshape the 1024 flat bytes back into a 32x32 grid
        feature_map = np.frombuffer(result_bytes, dtype=np.uint8).reshape((32, 32))
        
        # Normalize and threshold to find the strongest activation zones
        norm_map = cv2.normalize(feature_map, None, 0, 255, cv2.NORM_MINMAX)
        _, thresh = cv2.threshold(norm_map, 50, 255, cv2.THRESH_BINARY)
        
        # Find the contours (the detected zebra crossing shapes)
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        output_img = img.copy()
        
        for c in contours:
            if cv2.contourArea(c) > 5:
                # Get the bounding box from the 32x32 map
                x, y, w, h = cv2.boundingRect(c)
                
                # Scale coordinates up by 10 to fit the original 320x320 image
                sx, sy, sw, sh = x * 10, y * 10, w * 10, h * 10
                
                # Draw the distinct green rectangle and label
                cv2.rectangle(output_img, (sx, sy), (sx + sw, sy + sh), (0, 255, 0), 2)
                cv2.putText(output_img, "Zebra Crossing", (sx, max(sy - 10, 10)), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

        # Save to output folder
        raw_out_path = os.path.join(OUT_DIR, "fpga_raw_feature_map.png")
        box_out_path = os.path.join(OUT_DIR, "fpga_zebra_detected.png")
        cv2.imwrite(raw_out_path, norm_map)
        cv2.imwrite(box_out_path, output_img)
        print(f"Saved outputs to folder:\n - {raw_out_path}\n - {box_out_path}")
        
        # Pop up the windows on your screen! (Press any key to close them)
        cv2.imshow("FPGA Neural Feature Map", norm_map)
        cv2.imshow("Zebra Crossing Detection", output_img)
        cv2.waitKey(0)
        cv2.destroyAllWindows()
        
    except Exception as e:
        print(f"\nError: {e}")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()

if __name__ == "__main__":
    run_zebra_detection()