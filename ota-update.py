import os
import requests
import shutil
import time
import json

# Paths
BASE_PATH = r'C:\segformer_docker\dataset\TEST_SEG_OTA'
DEPOSIT_PATH = os.path.join(BASE_PATH, 'deposit')
MAIN_PATH = os.path.join(BASE_PATH, 'main')
LOGS_PATH = os.path.join(BASE_PATH, 'logs')
LAST_COMMIT_FILE = os.path.join(BASE_PATH, 'last_commit.json')

USER = 'vsaikiran234'
REPO = 'FR_SEG'
BRANCH = 'main'

FILES = [
    'Dockerfile',
    'epoch.ckpt',
    'segformer_script.py',
    'test_segformer.bat',
    'trial.mp4',
    'trial_output.mp4'
]

# --- ADD THIS LINE ---
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN') # Retrieve token from environment variable
# Alternatively, you could hardcode it here for testing, but NOT recommended for production:
GITHUB_TOKEN = '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'

def log_update(message):
    if not os.path.exists(LOGS_PATH):
        os.makedirs(LOGS_PATH)
    with open(os.path.join(LOGS_PATH, 'update_log.txt'), 'a', encoding='utf-8') as f:
        f.write(f'{time.ctime()}: {message}\n')
    print(message)

def get_commit_hash_for_file(file_path):
    url = f'https://api.github.com/repos/{USER}/{REPO}/commits?path={file_path}&sha={BRANCH}&per_page=1'
    log_update(f"Fetching commit hash from: {url}")
    
    # --- ADD THIS BLOCK FOR AUTHENTICATION ---
    headers = {}
    if GITHUB_TOKEN:
        headers['Authorization'] = f'token {GITHUB_TOKEN}'
    # --- END ADDITION ---

    try:
        r = requests.get(url, headers=headers) # Pass headers here
        if r.status_code == 200:
            commits = r.json()
            if isinstance(commits, list) and commits:
                return commits[0]['sha']
            else:
                log_update(f"No commits found for {file_path}")
        else:
            log_update(f"Failed to fetch commit for {file_path}: status {r.status_code}. Response: {r.text}")
    except requests.exceptions.RequestException as e:
        log_update(f"Network or request error fetching commit for {file_path}: {e}")
    except Exception as e:
        log_update(f"General error fetching commit for {file_path}: {e}")
    return None

def is_valid_python_file(content_bytes):
    try:
        content_str = content_bytes.decode('utf-8')
        return 'def ' in content_str or 'import ' in content_str or 'class ' in content_str
    except UnicodeDecodeError:
        return False

def download_file(file_name):
    raw_url = f'https://raw.githubusercontent.com/{USER}/{REPO}/{BRANCH}/{file_name}'
    dest = os.path.join(DEPOSIT_PATH, file_name)
    log_update(f"Downloading {file_name} from: {raw_url}")

    # --- ADD THIS BLOCK FOR AUTHENTICATION (for raw content) ---
    headers = {}
    if GITHUB_TOKEN:
        # Note: Raw content API might not strictly need 'token' prefix,
        # but it's good practice to include it for consistency with API calls.
        headers['Authorization'] = f'token {GITHUB_TOKEN}'
    # --- END ADDITION ---

    try:
        r = requests.get(raw_url, stream=True, headers=headers) # Pass headers here
        if r.status_code == 200:
            content = r.content
            if file_name.endswith('.py') and not is_valid_python_file(content):
                log_update(f"Aborted saving {file_name}: content does not look like valid Python code")
                return False
            with open(dest, 'wb') as f:
                f.write(content)
            log_update(f"Downloaded and saved {file_name}")
            return True
        else:
            log_update(f"Failed to download {file_name}: status {r.status_code}. Response: {r.text}")
    except requests.exceptions.RequestException as e:
        log_update(f"Network or request error downloading {file_name}: {e}")
    except Exception as e:
        log_update(f"General error downloading {file_name}: {e}")
    return False

def load_commit_data():
    if os.path.exists(LAST_COMMIT_FILE):
        try:
            with open(LAST_COMMIT_FILE, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            log_update(f"Error decoding last_commit.json: {e}")
            return {}
        except Exception as e:
            log_update(f"Error loading last_commit.json: {e}")
    return {}

def save_commit_data(commit_data):
    try:
        with open(LAST_COMMIT_FILE, 'w') as f:
            json.dump(commit_data, f, indent=2)
    except Exception as e:
        log_update(f"Error saving commit data: {e}")

def update_files():
    updated = False
    commit_data = load_commit_data()
    new_commit_data = {}

    if not os.path.exists(DEPOSIT_PATH):
        os.makedirs(DEPOSIT_PATH)

    for file in FILES:
        new_hash = get_commit_hash_for_file(file)
        old_hash = commit_data.get(file)
        new_commit_data[file] = new_hash

        if new_hash and (new_hash != old_hash or not os.path.exists(os.path.join(DEPOSIT_PATH, file))):
            log_update(f"Updating file: {file}")
            success = download_file(file)
            if success:
                updated = True
            else:
                log_update(f"Skipped file due to download failure: {file}")
        elif new_hash is None:
            log_update(f"Could not retrieve new commit hash for {file}. Skipping update for this file.")
        else:
            log_update(f"No update needed for: {file}")

    save_commit_data(new_commit_data)
    return updated

def clear_folder(path):
    if os.path.exists(path):
        try:
            shutil.rmtree(path)
            log_update(f"Deleted folder {path}")
        except OSError as e:
            log_update(f"Error deleting folder {path}: {e}")
    else:
        log_update(f"Folder {path} does not exist. No need to clear.")

def move_files_to_main():
    clear_folder(MAIN_PATH)
    try:
        os.makedirs(MAIN_PATH)
        for fname in os.listdir(DEPOSIT_PATH):
            shutil.move(os.path.join(DEPOSIT_PATH, fname), os.path.join(MAIN_PATH, fname))
        log_update("Moved files from deposit to main")
        clear_folder(DEPOSIT_PATH)
    except OSError as e:
        log_update(f"Error moving files to main or clearing deposit: {e}")

def main():
    log_update("Starting OTA update check...")
    files_updated = update_files()

    if files_updated or not os.path.exists(MAIN_PATH) or not os.listdir(MAIN_PATH):
        log_update("Refreshing main folder with latest files...")
        move_files_to_main()
        log_update("OTA update completed successfully.")
    else:
        log_update("No updates needed. Main folder is up-to-date.")

if __name__ == '__main__':
    main()