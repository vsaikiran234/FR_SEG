import os
import requests
import shutil
import json
import time
import logging
from functools import reduce

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# GitHub repository details
USER = "vsaikiran234"
REPO = "FR_SEG"
BRANCH = "main"
GITHUB_API_COMMITS_URL = f"https://api.github.com/repos/{USER}/{REPO}/commits?sha={BRANCH}"
GITHUB_RAW_URL = f"https://raw.githubusercontent.com/{USER}/{REPO}/{BRANCH}/segformer_script.py"

# Dynamic paths relative to script location
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEPOSIT_DIR = os.path.join(SCRIPT_DIR, "deposit")
MAIN_DIR = os.path.join(SCRIPT_DIR, "main")
DEPOSIT_SCRIPT_PATH = os.path.join(DEPOSIT_DIR, "segformer_script.py")
LOCAL_SCRIPT_PATH = os.path.join(MAIN_DIR, "segformer_script.py")
LAST_COMMIT_FILE = os.path.join(SCRIPT_DIR, "last_commit.json")

def get_latest_commit_hash():
    """
    Fetches the latest commit hash from the GitHub repository.
    Retries up to 3 times in case of failure.
    """
    retries = 3
    for attempt in range(retries):
        try:
            response = requests.get(GITHUB_API_COMMITS_URL, timeout=10)
            response.raise_for_status()
            commits = response.json()
            if isinstance(commits, list) and commits:
                return commits[0]["sha"]
            else:
                logger.error("No commits found in the repository.")
                return None
        except requests.RequestException as e:
            logger.error(f"Attempt {attempt + 1} failed: {e}")
            time.sleep(2)
    logger.error("All attempts to fetch commit hash failed.")
    return None

def download_segformer_script():
    """
    Downloads the latest segformer_script.py from GitHub to the deposit folder.
    """
    logger.info(f"Checking for updates to segformer_script.py from {GITHUB_RAW_URL}...")
    try:
        response = requests.get(GITHUB_RAW_URL, timeout=10)
        response.raise_for_status()
        new_content = response.text

        os.makedirs(DEPOSIT_DIR, exist_ok=True)
        if os.path.exists(DEPOSIT_SCRIPT_PATH):
            with open(DEPOSIT_SCRIPT_PATH, "r", encoding="utf-8") as file:
                existing_content = file.read()
            if existing_content == new_content:
                logger.info("No changes detected in segformer_script.py. Already up to date.")
                return False

        with open(DEPOSIT_SCRIPT_PATH, "w", encoding="utf-8") as file:
            file.write(new_content)
        logger.info("Updated deposit/segformer_script.py with the latest version from GitHub.")
        return True
    except requests.RequestException as e:
        logger.error(f"Failed to download file: {e}")
        return False

def deposit_files():
    """
    Scans the deposit directory for new files.
    """
    if not os.path.exists(DEPOSIT_DIR):
        return []
    return [f for f in os.listdir(DEPOSIT_DIR) if not f.startswith(".")]

def directory_tree(rootdir):
    """
    Generates a directory tree of the given directory.
    """
    directory = {}
    rootdir = rootdir.rstrip(os.sep)
    start = rootdir.rfind(os.sep) + 1
    for path, dirs, files in os.walk(rootdir):
        folders = path[start:].split(os.sep)
        subdir = dict.fromkeys(files)
        parent = reduce(dict.get, folders[:-1], directory)
        parent[folders[-1]] = subdir
    return directory

def move_dir(directory_tree, branch):
    """
    Recursively moves files from deposit to main directory.
    """
    for name in directory_tree:
        if ".keep" not in name and name != "last_commit.json":
            if "." in name:
                src = os.path.join(DEPOSIT_DIR, branch, name)
                dest = os.path.join(MAIN_DIR, branch, name)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.move(src, dest)
            else:
                move_dir(directory_tree[name], os.path.join(branch, name))
                try:
                    os.rmdir(os.path.join(DEPOSIT_DIR, branch, name))
                except OSError:
                    pass

def move_to_main():
    """
    Moves all files from deposit to the main directory.
    """
    tree = directory_tree(DEPOSIT_DIR)
    move_dir(tree["deposit"], "")
    logger.info("Main directory updated with new deposit files.")

def main():
    """
    Main function to check for updates and move files.
    """
    # Ensure directories exist
    os.makedirs(DEPOSIT_DIR, exist_ok=True)
    os.makedirs(MAIN_DIR, exist_ok=True)
    logger.info(f"Ensured directories: {DEPOSIT_DIR}, {MAIN_DIR}")

    # Get the latest commit hash
    latest_commit = get_latest_commit_hash()
    if not latest_commit:
        logger.error("Could not retrieve latest commit hash. Using existing script if available.")
        return

    logger.info(f"Latest commit hash: {latest_commit}")

    # Check for new commit
    last_commit = None
    if os.path.exists(LAST_COMMIT_FILE):
        with open(LAST_COMMIT_FILE, "r", encoding="utf-8") as f:
            last_commit = f.read().strip()

    if last_commit != latest_commit:
        logger.info("New commit detected. Downloading the latest segformer_script.py...")
        if download_segformer_script():
            with open(LAST_COMMIT_FILE, "w", encoding="utf-8") as f:
                f.write(latest_commit)
            if deposit_files():
                move_to_main()
    else:
        logger.info("Already up to date with the latest commit.")

    # If main/segformer_script.py doesn't exist, copy from repo root if available
    if not os.path.exists(LOCAL_SCRIPT_PATH):
        repo_script_path = os.path.join(SCRIPT_DIR, "segformer_script.py")
        if os.path.exists(repo_script_path):
            os.makedirs(MAIN_DIR, exist_ok=True)
            shutil.copy(repo_script_path, LOCAL_SCRIPT_PATH)
            logger.info(f"Copied segformer_script.py from repo root to {LOCAL_SCRIPT_PATH}")

if __name__ == "__main__":
    main()
