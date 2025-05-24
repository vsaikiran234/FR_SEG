@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: IMPORTANT: This batch file is designed to be run from WITHIN THE 'main' folder
:: after ota-update.py has placed all files there.

:: Define paths relative to the current directory (which is 'main' INSIDE THE CONTAINER)
:: These are the paths where the files are expected to be after OTA updates them into 'main'.
SET "CKPT=epoch.ckpt"
SET "INPUT=trial.mp4"
SET "OUTPUT=trial_output.mp4"

ECHO [*] Checkpoint   = %CKPT%
ECHO [*] Input video  = %INPUT%
ECHO [*] Output video = %OUTPUT%

:: Clear previous build log, relative to current execution path (main)
ECHO. > build_logs.txt

(
    :: Determine the base directory where Dockerfile is located (one level up from 'main')
    FOR %%i IN ("%~dp0.") DO SET "BASE_DIR_FOR_DOCKERFILE=%%~dpi"

    :: Build Docker image if it doesn't exist or if Dockerfile has changed.
    :: The Dockerfile is expected in the parent directory (one level up from 'main').
    docker image inspect segformer >nul 2>&1
    IF %ERRORLEVEL% NEQ 0 (
        ECHO [*] Building Docker image 'segformer'...
        :: Build context is the parent directory where the Dockerfile is located.
        docker build -t segformer "%BASE_DIR_FOR_DOCKERFILE%"
    ) ELSE (
        ECHO [^✓] Docker image 'segformer' already exists. Skipping build.
    )

    :: Run Docker container
    :: Mount the current directory (which is 'main') into /app inside the container.
    :: "%~dp0" resolves to the full path of the current directory (e.g., C:\segformer_docker\dataset\FR_SEG_OTA_2\main\)
    docker run --rm -it --gpus all ^
      -v "%~dp0":/app ^
      segformer python3 /app/segformer_script.py ^
      "/app/%CKPT%" ^
      "/app/%INPUT%" ^
      "/app/%OUTPUT%"
) >> build_logs.txt 2>&1

ENDLOCAL
