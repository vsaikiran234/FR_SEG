@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Define relative paths (relative to current directory)
SET "SCRIPT_DIR=%CD%"
SET "MAIN_DIR=%SCRIPT_DIR%\main"
SET "CKPT=%MAIN_DIR%\epoch.ckpt"
SET "INPUT=%MAIN_DIR%\trial.mp4"
SET "OUTPUT=%MAIN_DIR%\trial_output.mp4"
SET "SCRIPT=%MAIN_DIR%\segformer_script.py"
SET "LOG_FILE=%MAIN_DIR%\temp_fps.log"
SET "JSON_FILE=%MAIN_DIR%\fps_log.json"

:: Ensure main directory exists
IF NOT EXIST "%MAIN_DIR%" (
    mkdir "%MAIN_DIR%"
    echo [*] Created main directory: %MAIN_DIR%
)

:: Move input files from repo root to main if not already present
IF NOT EXIST "%CKPT%" (
    IF EXIST "%SCRIPT_DIR%\epoch.ckpt" (
        move "%SCRIPT_DIR%\epoch.ckpt" "%CKPT%"
        echo [*] Moved epoch.ckpt to %MAIN_DIR%
    ) ELSE (
        echo [X] Checkpoint file not found: %SCRIPT_DIR%\epoch.ckpt
        exit /b 1
    )
)
IF NOT EXIST "%INPUT%" (
    IF EXIST "%SCRIPT_DIR%\trial.mp4" (
        move "%SCRIPT_DIR%\trial.mp4" "%INPUT%"
        echo [*] Moved trial.mp4 to %MAIN_DIR%
    ) ELSE (
        echo [X] Input video not found: %SCRIPT_DIR%\trial.mp4
        exit /b 1
    )
)

echo [*] Checkpoint   = %CKPT%
echo [*] Input video  = %INPUT%
echo [*] Output video = %OUTPUT%
echo [*] Script       = %SCRIPT%
echo [*] JSON output  = %JSON_FILE%

:: Verify checkpoint file integrity
echo [*] Verifying checkpoint file...
python -c "import torch; checkpoint = torch.load('%CKPT%'.replace('\\', '/'), map_location='cpu'); print('Checkpoint keys:', list(checkpoint.keys()))" >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [X] Invalid checkpoint file: %CKPT%. Please replace with a valid PyTorch checkpoint.
    exit /b 1
)
echo [✓] Checkpoint file verified successfully.

:: Run OTA update script to fetch latest segformer_script.py
echo [*] Checking for OTA updates...
python "%SCRIPT_DIR%\ota-update.py"
IF %ERRORLEVEL% NEQ 0 (
    echo [X] OTA update script failed.
    exit /b 1
)

:: Check if segformer_script.py exists in main
IF NOT EXIST "%SCRIPT%" (
    echo [X] segformer_script.py not found in %MAIN_DIR%
    exit /b 1
)

:: Build Docker image if it doesn't exist
docker image inspect segformer >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [*] Building Docker image 'segformer'...
    docker build -t segformer .
    IF %ERRORLEVEL% NEQ 0 (
        echo [X] Failed to build Docker image
        exit /b 1
    )
) ELSE (
    echo [✓] Docker image 'segformer' already exists. Skipping build.
)

:: Create Python script to parse logs and generate JSON
echo import json, re, os > "%SCRIPT_DIR%\parse_fps.py"
echo log_file = r'%LOG_FILE%' >> "%SCRIPT_DIR%\parse_fps.py"
echo json_file = r'%JSON_FILE%' >> "%SCRIPT_DIR%\parse_fps.py"
echo frames = {} >> "%SCRIPT_DIR%\parse_fps.py"
echo if os.path.exists(log_file): >> "%SCRIPT_DIR%\parse_fps.py"
echo     with open(log_file, 'r', encoding='utf-8') as f: >> "%SCRIPT_DIR%\parse_fps.py"
echo         for line in f: >> "%SCRIPT_DIR%\parse_fps.py"
echo             match = re.match(r'\[Frame (\d+)\] CURRENT RATE FPS: ([\d.]+)', line.strip()) >> "%SCRIPT_DIR%\parse_fps.py"
echo             if match: >> "%SCRIPT_DIR%\parse_fps.py"
echo                 frame_num = match.group(1) >> "%SCRIPT_DIR%\parse_fps.py"
echo                 fps = float(match.group(2)) >> "%SCRIPT_DIR%\parse_fps.py"
echo                 frames[frame_num] = {'frame': frame_num, 'fps': fps} >> "%SCRIPT_DIR%\parse_fps.py"
echo with open(json_file, 'w', encoding='utf-8') as f: >> "%SCRIPT_DIR%\parse_fps.py"
echo     json.dump({'frames': frames}, f, indent=4) >> "%SCRIPT_DIR%\parse_fps.py"

:: Run Docker container and redirect output to log file
echo [*] Running Docker container and logging FPS...
docker run --rm -it --gpus all ^
    -v "%SCRIPT_DIR%:/home/segformer_docker/TEST_SEG_OTA" ^
    segformer python3 /home/segformer_docker/TEST_SEG_OTA/main/segformer_script.py ^
    "/home/segformer_docker/TEST_SEG_OTA/main/epoch.ckpt" ^
    "/home/segformer_docker/TEST_SEG_OTA/main/trial.mp4" ^
    "/home/segformer_docker/TEST_SEG_OTA/main/trial_output.mp4" > "%LOG_FILE%" 2>&1

IF %ERRORLEVEL% NEQ 0 (
    echo [X] Docker container execution failed
    type "%LOG_FILE%"
    exit /b 1
)

:: Parse log file to generate JSON
echo [*] Generating FPS JSON file...
python "%SCRIPT_DIR%\parse_fps.py"
IF %ERRORLEVEL% NEQ 0 (
    echo [X] Failed to generate FPS JSON file
    type "%LOG_FILE%"
    exit /b 1
)

:: Clean up temporary files
del "%LOG_FILE%" >nul 2>&1
del "%SCRIPT_DIR%\parse_fps.py" >nul 2>&1

echo [✔] Video processing completed. Output saved at %OUTPUT%
echo [✔] FPS log saved at %JSON_FILE%
ENDLOCAL
