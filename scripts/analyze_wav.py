import wave
import sys
import os

file_path = r"C:\Flutter\Projects\madbunky_pro\assets\Notification\madbunky.wav"

try:
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        sys.exit(1)
        
    with wave.open(file_path, 'rb') as wav_file:
        print(f"Channels: {wav_file.getnchannels()}")
        print(f"Sample Width: {wav_file.getsampwidth()} bytes ({(wav_file.getsampwidth() * 8)} bits)")
        print(f"Frame Rate: {wav_file.getframerate()} Hz")
        print(f"Number of Frames: {wav_file.getnframes()}")
        print(f"Duration: {wav_file.getnframes() / wav_file.getframerate():.2f} seconds")
        print(f"Compression Type: {wav_file.getcomptype()} ({wav_file.getcompname()})")

except wave.Error as e:
    print(f"WAVE Error: {e}")
except Exception as e:
    print(f"General Error: {e}")
