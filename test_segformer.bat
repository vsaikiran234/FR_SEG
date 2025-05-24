@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Hardcoded paths (pointing to main folder)
SET "CKPT=main/epoch.ckpt"
SET "INPUT=main/trial.mp4"
SET "OUTPUT=main/trial_output.mp4"

echo [*] Checkpoint   = %CKPT%
echo [*] Input video  = %INPUT%
echo [*] Output video = %OUTPUT%

:: Run OTA update script before proceeding
echo [*] Checking for OTA updates...
python ota-update.py

:: Build Docker image if it doesn't exist
docker image inspect segformer >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [*] Building Docker image 'segformer'...
    docker build -t segformer .
) ELSE (
    echo [✓] Docker image 'segformer' already exists. Skipping build.
)

:: Run Docker container with updated main folder paths
docker run --rm -it --gpus all ^
  -v "%cd%":/home/segformer_docker/TEST_SEG_OTA ^
  segformer python3 /home/segformer_docker/TEST_SEG_OTA/segformer_script.py ^
  "/home/segformer_docker/TEST_SEG_OTA/%CKPT%" ^
  "/home/segformer_docker/TEST_SEG_OTA/%INPUT%" ^
  "/home/segformer_docker/TEST_SEG_OTA/%OUTPUT%"

ENDLOCAL
