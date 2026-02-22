from PIL import Image
import os

def create_notification_icon(input_path, output_path):
    try:
        img = Image.open(input_path).convert("RGBA")
        datas = img.getdata()

        new_data = []
        for item in datas:
            # Change all non-transparent pixels to black
            if item[3] > 0:  # If alpha is not 0
                new_data.append((0, 0, 0, item[3])) # Keep alpha, set RGB to black
            else:
                new_data.append(item)

        img.putdata(new_data)
        
        # Resize to something reasonable for a notification icon (e.g. 96x96 for xhdpi generic)
        # Android allows various sizes, but let's base it on the original size or a safe max.
        # Assuming original is high res, let's just save it. Android will scale or we can resize.
        # Ideally we should make it small and placed in drawable folder.
        # 1024x1024 is too big. Let's resize to 96x96 for simplicity as a base drawable.
        img = img.resize((96, 96), Image.Resampling.LANCZOS)
        
        img.save(output_path, "PNG")
        print(f"Successfully created {output_path}")
    except Exception as e:
        print(f"Error: {e}")

input_file = r"c:\Flutter\Projects\madbunky_pro\assets\icon\mb.png"
output_file = r"c:\Flutter\Projects\madbunky_pro\assets\icon\notification_icon.png"
android_output_file = r"c:\Flutter\Projects\madbunky_pro\android\app\src\main\res\drawable\notification_icon.png"

create_notification_icon(input_file, output_file)
create_notification_icon(input_file, android_output_file)
