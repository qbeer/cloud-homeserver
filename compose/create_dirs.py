from pathlib import Path
import yaml

def create_dirs(volume_path):
    local_path = volume_path.split(':')[0]
    if Path(local_path).exists():
        return
    
    if '$' in local_path:
        return
    
    Path(local_path).mkdir(parents=True, exist_ok=True)
    
if __name__ == '__main__':
    compose_file = './compose.yaml'
    
    with open(compose_file) as file:
        compose = yaml.load(file, Loader=yaml.FullLoader)
        
    for service in compose['services']:
        if 'volumes' in compose['services'][service]:
            for volume in compose['services'][service]['volumes']:
                create_dirs(volume)
                
    