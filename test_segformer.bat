@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Base path is the location of this script
SET "BASE_DIR=%~dp0"
PUSHD "%BASE_DIR%"

SET "CKPT=main/epoch.ckpt"
SET "INPUT=main/trial.mp4"
SET "OUTPUT=main/trial_output.mp4"

echo [*] Checkpoint   = %CKPT%
echo [*] Input video  = %INPUT%
echo [*] Output video = %OUTPUT%

:: Run OTA update
echo [*] Checking for OTA updates...
python ota-update.py

:: Build Docker image if not already present
docker image inspect segformer >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [*] Building Docker image 'segformer'...
    docker build -t segformer .
) ELSE (
    echo [✓] Docker image 'segformer' already exists.
)

:: Run Docker container with mounted volume
docker run --rm -it --gpus all ^
  -v "%BASE_DIR%:/workspace" ^
  segformer python3 /workspace/main/segformer_script.py ^
  "/workspace/%CKPT%" ^
  "/workspace/%INPUT%" ^
  "/workspace/%OUTPUT%"

POPD
ENDLOCAL
