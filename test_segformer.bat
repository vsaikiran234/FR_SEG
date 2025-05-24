@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: IMPORTANT: This batch file is designed to be run from WITHIN THE 'main' folder
:: after ota-update.py has placed all files there.

:: Define file names that are expected to be in the 'main' folder
SET "CKPT_FILENAME=epoch.ckpt"
SET "INPUT_FILENAME=trial.mp4"
SET "OUTPUT_FILENAME=trial_output.mp4"

ECHO [*] Checkpoint   = %CKPT_FILENAME%
ECHO [*] Input video  = %INPUT_FILENAME%
ECHO [*] Output video = %OUTPUT_FILENAME%

:: Clear previous build log, relative to current execution path (main)
ECHO. > build_logs.txt

(
    :: Determine the base directory where Dockerfile is located (one level up from 'main')
    :: "%~dp0" is the path to the current batch file (e.g., C:\base\main\)
    :: The "FOR /F" loop extracts the parent directory (e.g., C:\base\)
    FOR %%A IN ("%~dp0.") DO SET "BASE_DIR_FOR_DOCKERFILE=%%~dpA"

    :: Build Docker image if it doesn't exist or if Dockerfile has changed.
    :: The Dockerfile is expected in the parent directory of 'main'.
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
      "/app/%CKPT_FILENAME%" ^
      "/app/%INPUT_FILENAME%" ^
      "/app/%OUTPUT_FILENAME%"
) >> build_logs.txt 2>&1

ENDLOCAL
