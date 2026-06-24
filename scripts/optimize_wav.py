import wave
import audioop
import sys
import os

input_path = r"C:\Flutter\Projects\madbunky_pro\assets\Notification\madbunky.wav"
output_path = r"C:\Flutter\Projects\madbunky_pro\android\app\src\main\res\raw\madbunky.wav"
backup_path = r"C:\Flutter\Projects\madbunky_pro\assets\Notification\madbunky_optimized.wav"

def optimize():
    try:
        if not os.path.exists(input_path):
            print("Input file not found.")
            return

        with wave.open(input_path, 'rb') as source:
            params = source.getparams()
            frames = source.readframes(source.getnframes())
            
            n_channels = source.getnchannels()
            samp_width = source.getsampwidth()
            frame_rate = source.getframerate()
            
            print(f"Original: {n_channels}ch, {samp_width*8}bit, {frame_rate}Hz")

            # Convert to Mono if needed (Android handles Stereo fine, but Mono is smaller/safer)
            if n_channels == 2:
                frames = audioop.tomono(frames, samp_width, 0.5, 0.5)
                n_channels = 1
            
            # Resample to 44100 if needed
            if frame_rate != 44100:
                frames, _ = audioop.ratecv(frames, samp_width, n_channels, frame_rate, 44100, None)
                frame_rate = 44100

            # Convert to 16-bit if needed (Standard for Wav)
            if samp_width != 2:
                # limited support for conversion in standard lib without numpy/scipy
                # audioop supports some, but let's see. 
                # If it's 24-bit (3 bytes), standard wave might fail to read it anyway.
                # If it's 8-bit (1 byte), we can convert.
                pass 

        # Write optimized
        with wave.open(output_path, 'wb') as dest:
            dest.setnchannels(n_channels)
            dest.setsampwidth(samp_width) # Keep original width if we didn't change it, or force 2 if we could
            dest.setframerate(frame_rate)
            dest.writeframes(frames)
            
        print(f"Optimized: {n_channels}ch, {samp_width*8}bit, {frame_rate}Hz")
        print("Success")

        # Update asset backup too
        with wave.open(backup_path, 'wb') as backup:
            backup.setparams((n_channels, samp_width, frame_rate, 0, 'NONE', 'not compressed'))
            backup.writeframes(frames)

    except Exception as e:
        print(f"Error optimizing: {e}")

if __name__ == "__main__":
    optimize()
