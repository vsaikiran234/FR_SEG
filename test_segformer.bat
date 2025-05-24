@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Define relative paths (relative to current directory)
SET "SCRIPT_DIR=%CD%"
SET "MAIN_DIR=%SCRIPT_DIR%\main"
SET "CKPT=%MAIN_DIR%\epoch.ckpt"
SET "INPUT=%MAIN_DIR%\trial.mp4"
SET "OUTPUT=%MAIN_DIR%\trial_output.mp4"
SET "SCRIPT=%MAIN_DIR%\segformer_script.py"

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

:: Run Docker container with dynamic paths
docker run --rm -it --gpus all ^
  -v "%SCRIPT_DIR%:/home/segformer_docker/TEST_SEG_OTA" ^
  segformer python3 /home/segformer_docker/TEST_SEG_OTA/main/segformer_script.py ^
  "/home/segformer_docker/TEST_SEG_OTA/main/epoch.ckpt" ^
  "/home/segformer_docker/TEST_SEG_OTA/main/trial.mp4" ^
  "/home/segformer_docker/TEST_SEG_OTA/main/trial_output.mp4"

IF %ERRORLEVEL% NEQ 0 (
    echo [X] Docker container execution failed
    exit /b 1
)

echo [✓] Video processing completed. Output saved at %OUTPUT%
ENDLOCAL
