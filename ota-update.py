import os
import requests
import shutil
import time
import json

# Dynamic base path: where this script is located
BASE_PATH = os.path.dirname(os.path.abspath(__file__))
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

# Secure token handling
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
GITHUB_TOKEN = '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'
def log_update(message):
    if not os.path.exists(LOGS_PATH):
        os.makedirs(LOGS_PATH)
    with open(os.path.join(LOGS_PATH, 'update_log.txt'), 'a', encoding='utf-8') as f:
        f.write(f'{time.ctime()}: {message}\n')
    print(message)

def get_commit_hash_for_file(file_path):
    url = f'https://api.github.com/repos/{USER}/{REPO}/commits?path={file_path}&sha={BRANCH}&per_page=1'
    headers = {'Authorization': f'token {GITHUB_TOKEN}'} if GITHUB_TOKEN else {}

    try:
        r = requests.get(url, headers=headers)
        if r.status_code == 200:
            commits = r.json()
            if isinstance(commits, list) and commits:
                return commits[0]['sha']
            else:
                log_update(f"No commits found for {file_path}")
        else:
            log_update(f"Failed to fetch commit for {file_path}: status {r.status_code}. Response: {r.text}")
    except Exception as e:
        log_update(f"Error fetching commit for {file_path}: {e}")
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
    headers = {'Authorization': f'token {GITHUB_TOKEN}'} if GITHUB_TOKEN else {}

    try:
        r = requests.get(raw_url, stream=True, headers=headers)
        if r.status_code == 200:
            content = r.content
            if file_name.endswith('.py') and not is_valid_python_file(content):
                log_update(f"Invalid Python file content: {file_name}")
                return False
            with open(dest, 'wb') as f:
                f.write(content)
            log_update(f"Downloaded: {file_name}")
            return True
        else:
            log_update(f"Failed to download {file_name}: status {r.status_code}")
    except Exception as e:
        log_update(f"Error downloading {file_name}: {e}")
    return False

def load_commit_data():
    if os.path.exists(LAST_COMMIT_FILE):
        try:
            with open(LAST_COMMIT_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            log_update(f"Error loading commit data: {e}")
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

    os.makedirs(DEPOSIT_PATH, exist_ok=True)

    for file in FILES:
        new_hash = get_commit_hash_for_file(file)
        old_hash = commit_data.get(file)
        new_commit_data[file] = new_hash

        if new_hash and (new_hash != old_hash or not os.path.exists(os.path.join(DEPOSIT_PATH, file))):
            log_update(f"Updating: {file}")
            success = download_file(file)
            if success:
                updated = True
        elif new_hash is None:
            log_update(f"Skipped (no hash found): {file}")
        else:
            log_update(f"Up-to-date: {file}")

    save_commit_data(new_commit_data)
    return updated

def clear_folder(path):
    if os.path.exists(path):
        try:
            shutil.rmtree(path)
            log_update(f"Cleared: {path}")
        except Exception as e:
            log_update(f"Error clearing folder {path}: {e}")

def move_files_to_main():
    clear_folder(MAIN_PATH)
    os.makedirs(MAIN_PATH, exist_ok=True)
    for fname in os.listdir(DEPOSIT_PATH):
        shutil.move(os.path.join(DEPOSIT_PATH, fname), os.path.join(MAIN_PATH, fname))
    log_update("Moved files to main folder")
    clear_folder(DEPOSIT_PATH)

def main():
    log_update("Starting OTA update...")
    files_updated = update_files()
    if files_updated or not os.path.exists(MAIN_PATH) or not os.listdir(MAIN_PATH):
        log_update("Applying file updates...")
        move_files_to_main()
    else:
        log_update("All files are up-to-date.")

if __name__ == '__main__':
    main()
