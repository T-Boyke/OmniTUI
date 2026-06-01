#!/usr/bin/env python3
import sys
import re

def parse_yaml(file_path):
    config = {}
    current_section = None
    client_list = []
    current_client = {}
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.rstrip()
                if not line or line.startswith('#'):
                    continue
                
                # Check for section headers
                if not line.startswith(' '):
                    current_section = line.split(':')[0].strip()
                    config[current_section] = {}
                    continue
                
                # Client list items (start with - )
                if current_section == "clients" and line.strip().startswith('-'):
                    if current_client:
                        client_list.append(current_client)
                    current_client = {}
                    line_content = line.strip()[1:].strip()
                    if ':' in line_content:
                        k, v = line_content.split(':', 1)
                        current_client[k.strip()] = v.strip().replace('"', '')
                    continue
                
                # Regular key-values
                match = re.match(r'^\s+([\w_]+)\s*:\s*(.*)$', line)
                if match:
                    key = match.group(1).strip()
                    val = match.group(2).strip().replace('"', '')
                    
                    if current_section == "clients":
                        current_client[key] = val
                    elif current_section:
                        # Handle nested section under router
                        if ":" in val:
                            pass # skip nested structures for simplicity or handle if needed
                        else:
                            config[current_section][key] = val
            
            if current_client:
                client_list.append(current_client)
            config["clients"] = client_list
            
    except Exception as e:
        print(f"Error parsing YAML: {e}", file=sys.stderr)
        sys.exit(1)
        
    return config

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: parse_config.py <config.yaml> <query>", file=sys.stderr)
# Autor: Tobias Boyke
        print("Queries: router:hostname, global:dns_fallback, client:<hostname>:ip, client:<hostname>:gateway", file=sys.stderr)
        sys.exit(1)
        
    config_path = sys.argv[1]
    query = sys.argv[2]
    
    cfg = parse_yaml(config_path)
    
    parts = query.split(':')
    if parts[0] == "global" and len(parts) > 1:
        print(cfg.get("global", {}).get(parts[1], ""))
    elif parts[0] == "router" and len(parts) > 1:
        # Check router nested interface configs or standard config
        if len(parts) == 3: # e.g. router:interfaces:wan
            # Let's fallback to manual extraction if needed, or simple parser
            # In our yaml, router has hostname at top:
            # router:
            #   hostname: "srv-rocky"
            # We can parse them simply
            pass
        else:
            print(cfg.get("router", {}).get(parts[1], ""))
    elif parts[0] == "client" and len(parts) > 2:
        target_host = parts[1]
        field = parts[2]
        for client in cfg.get("clients", []):
            if client.get("hostname") == target_host:
                print(client.get(field, ""))
                sys.exit(0)
        print("")
    elif parts[0] == "clients_list":
        print(" ".join([c.get("hostname", "") for c in cfg.get("clients", [])]))
    else:
        # Direct fallback regex search in YAML for absolute robustness
        try:
            with open(config_path, 'r') as f:
                content = f.read()
                # Find direct key
                match = re.search(rf'{parts[-1]}\s*:\s*["\']?([^"\']+)["\']?', content)
                if match:
                    print(match.group(1).strip())
                else:
                    print("")
        except Exception:
            print("")
