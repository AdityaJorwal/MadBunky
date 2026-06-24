@echo off
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "C:\Users\Aditya\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android > sha_output.txt 2>&1
echo Done.
