from pathlib import Path
import yaml
import os

def load_env_file(filepath):
    if not filepath.exists():
        return
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, value = line.split('=', 1)
                os.environ[key.strip()] = value.strip()

# Load environment variables from .env file in the parent directory
env_path = Path(__file__).parent.parent / '.env'
load_env_file(env_path)

def create_dirs(volume_path):
    # Expand shell variables like ${ROOT_DIR}
    expanded_path = os.path.expandvars(volume_path)
    local_path = expanded_path.split(':')[0]
    
    if Path(local_path).exists():
        return
    
    # Skip if variable expansion failed or it's not a path we want to create
    if '$' in local_path:
        return
    
    try:
        Path(local_path).mkdir(parents=True, exist_ok=True)
        print(f"Created directory: {local_path}")
    except Exception as e:
        print(f"Error creating {local_path}: {e}")
    
if __name__ == '__main__':
    # compose file is now in the parent directory
    compose_file = Path(__file__).parent.parent / 'docker-compose.yml'
    
    if not compose_file.exists():
        print(f"Error: {compose_file} not found")
        exit(1)

    with open(compose_file) as file:
        compose = yaml.load(file, Loader=yaml.FullLoader)
        
    for service, config in compose.get('services', {}).items():
        if 'volumes' in config:
            for volume in config['volumes']:
                # Handle both short syntax (string) and long syntax (dict)
                if isinstance(volume, str):
                    create_dirs(volume)
                elif isinstance(volume, dict):
                    create_dirs(volume.get('source', ''))
                
    