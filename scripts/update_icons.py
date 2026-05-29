import shutil
import os

source = r'c:\Flutter\Projects\madbunky_pro\assets\icon\mb.png'
destinations = [
    r'c:\Flutter\Projects\madbunky_pro\android\app\src\main\res\mipmap-mdpi\ic_launcher.png',
    r'c:\Flutter\Projects\madbunky_pro\android\app\src\main\res\mipmap-hdpi\ic_launcher.png',
    r'c:\Flutter\Projects\madbunky_pro\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png',
    r'c:\Flutter\Projects\madbunky_pro\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png',
    r'c:\Flutter\Projects\madbunky_pro\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png',
]

notification_icon = r'c:\Flutter\Projects\madbunky_pro\assets\icon\notification_icon.png'
drawable_icon = r'c:\Flutter\Projects\madbunky_pro\android\app\src\main\res\drawable\notification_icon.png'

print(f"Source: {source} (Size: {os.path.getsize(source) if os.path.exists(source) else 'MISSING'})")

for dest in destinations:
    try:
        shutil.copy(source, dest)
        print(f"Copied to {dest}")
    except Exception as e:
        print(f"Error copying to {dest}: {e}")

if os.path.exists(notification_icon):
    try:
        os.remove(notification_icon)
        print(f"Deleted {notification_icon}")
    except Exception as e:
        print(f"Error deleting {notification_icon}: {e}")

if os.path.exists(drawable_icon):
    try:
        os.remove(drawable_icon)
        print(f"Deleted {drawable_icon}")
    except Exception as e:
        print(f"Error deleting {drawable_icon}: {e}")
