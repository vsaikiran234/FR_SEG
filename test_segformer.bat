@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: IMPORTANT: This batch file is designed to be run from WITHIN THE 'main' folder
:: after ota-update.py has placed all files there.

:: Define file names that are expected to be in the 'main' folder
SET "CKPT_FILENAME=epoch.ckpt"
SET "INPUT_FILENAME=trial.mp4"
SET "OUTPUT_FILENAME=trial_output.mp4"

ECHO [*] --- DEBUGGING PATHS ---
ECHO [*] Current Directory (%%cd%%): %cd%
ECHO [*] Batch file path (%%~dp0): %~dp0
ECHO [*] Checkpoint Filename: %CKPT_FILENAME%
ECHO [*] Input Filename: %INPUT_FILENAME%
ECHO [*] Output Filename: %OUTPUT_FILENAME%
ECHO [*] -----------------------

:: Clear previous build log, relative to current execution path (main)
ECHO. > build_logs.txt

(
    :: Determine the base directory where Dockerfile is located (one level up from 'main')
    :: "%~dp0" is the path to the current batch file (e.g., C:\base\main\)
    :: The "FOR /F" loop extracts the parent directory (e.g., C:\base\)
    FOR %%A IN ("%~dp0.") DO SET "BASE_DIR_FOR_DOCKERFILE=%%~dpA"
    ECHO [*] Dockerfile Base Dir: %BASE_DIR_FOR_DOCKERFILE%

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

    :: Construct paths for Docker container
    SET "CKPT_PATH_IN_CONTAINER=/app/%CKPT_FILENAME%"
    SET "INPUT_PATH_IN_CONTAINER=/app/%INPUT_FILENAME%"
    SET "OUTPUT_PATH_IN_CONTAINER=/app/%OUTPUT_FILENAME%"

    ECHO [*] Checkpoint Path in Container: %CKPT_PATH_IN_CONTAINER%
    ECHO [*] Input Path in Container: %INPUT_PATH_IN_CONTAINER%
    ECHO [*] Output Path in Container: %OUTPUT_PATH_IN_CONTAINER%


    :: Run Docker container
    :: Mount the current directory (which is 'main') into /app inside the container.
    :: "%~dp0" resolves to the full path of the current directory (e.g., C:\segformer_docker\dataset\FR_SEG_OTA_2\main\)
    docker run --rm -it --gpus all ^
      -v "%~dp0":/app ^
      segformer python3 /app/segformer_script.py ^
      "%CKPT_PATH_IN_CONTAINER%" ^
      "%INPUT_PATH_IN_CONTAINER%" ^
      "%OUTPUT_PATH_IN_CONTAINER%"
) >> build_logs.txt 2>&1

ENDLOCAL
