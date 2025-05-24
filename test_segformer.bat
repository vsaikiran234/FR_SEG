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
    FOR %%A IN ("%~dp0.") DO SET "BASE_DIR_FOR_DOCKERFILE=%%~dpA"

    :: Build Docker image if it doesn't exist or if Dockerfile has changed.
    docker image inspect segformer >nul 2>&1
    IF %ERRORLEVEL% NEQ 0 (
        ECHO [*] Building Docker image 'segformer'...
        docker build -t segformer "%BASE_DIR_FOR_DOCKERFILE%"
    ) ELSE (
        ECHO [^✓] Docker image 'segformer' already exists. Skipping build.
    )

    :: Construct paths for Docker container
    SET "CKPT_PATH_IN_CONTAINER=/app/%CKPT_FILENAME%"
    SET "INPUT_PATH_IN_CONTAINER=/app/%INPUT_FILENAME%"
    SET "OUTPUT_PATH_IN_CONTAINER=/app/%OUTPUT_FILENAME%"

    :: Run Docker container - ALL ON ONE LINE TO AVOID LINE CONTINUATION ISSUES
    docker run --rm -it --gpus all -v "%~dp0":/app segformer python3 /app/segformer_script.py "%CKPT_PATH_IN_CONTAINER%" "%INPUT_PATH_IN_CONTAINER%" "%OUTPUT_PATH_IN_CONTAINER%"
) >> build_logs.txt 2>&1

ENDLOCAL
