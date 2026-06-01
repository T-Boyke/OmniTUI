#!/usr/bin/env python3
# Autor: Tobias Boyke
# Zweck: Sicheres, robustes Schreiben von Werten in die config.yaml ohne externe AbhÃ¤ngigkeiten

import sys
import os
import re

def update_yaml_value(file_path, key_path, new_value):
    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found.", file=sys.stderr)
        return False
        
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        parts = key_path.split(':')
        updated = False
        
        # 1. Update global values
        if parts[0] == "global" and len(parts) > 1:
            target_key = parts[1]
            for i, line in enumerate(lines):
                if line.strip().startswith(f"{target_key}:"):
                    indent = len(line) - len(line.lstrip())
                    lines[i] = f"{' ' * indent}{target_key}: \"{new_value}\"\n"
                    updated = True
                    break
                    
        # 2. Update router values
        elif parts[0] == "router" and len(parts) > 1:
            # e.g. router:lan_a:ip
            in_router = False
            in_interface = None
            for i, line in enumerate(lines):
                strip = line.strip()
                if strip.startswith("router:"):
                    in_router = True
                    continue
                if in_router and not line.startswith(' '):
                    in_router = False
                    
                if in_router:
                    # Check if we are in interface block
                    if len(parts) == 3: # router:<interface>:<field>
                        target_if = parts[1]
                        target_field = parts[2]
                        if strip.startswith(f"{target_if}:"):
                            in_interface = target_if
                            continue
                        if in_interface and not line.startswith('    '):
                            in_interface = None
                            
                        if in_interface == target_if and strip.startswith(f"{target_field}:"):
                            indent = len(line) - len(line.lstrip())
                            lines[i] = f"{' ' * indent}{target_field}: \"{new_value}\"\n"
                            updated = True
                            break
                    else: # router:hostname
                        target_key = parts[1]
                        if strip.startswith(f"{target_key}:"):
                            indent = len(line) - len(line.lstrip())
                            lines[i] = f"{' ' * indent}{target_key}: \"{new_value}\"\n"
                            updated = True
                            break
                            
        # 3. Update client values
        elif parts[0] == "client" and len(parts) > 2:
            # client:<hostname>:<field>
            target_host = parts[1]
            target_field = parts[2]
            in_clients = False
            current_client_matched = False
            
            for i, line in enumerate(lines):
                strip = line.strip()
                if strip.startswith("clients:"):
                    in_clients = True
                    continue
                
                if in_clients:
                    # Check if new client block starts
                    if strip.startswith("- hostname:"):
                        host_val = strip.split(':', 1)[1].strip().replace('"', '')
                        if host_val == target_host:
                            current_client_matched = True
                        else:
                            current_client_matched = False
                            
                    if current_client_matched and strip.startswith(f"{target_field}:"):
                        indent = len(line) - len(line.lstrip())
                        lines[i] = f"{' ' * indent}{target_field}: \"{new_value}\"\n"
                        updated = True
                        break
                        
        if updated:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            print(f"Successfully updated {key_path} to '{new_value}' in config.yaml")
            return True
        else:
            print(f"Key path {key_path} not found in config.yaml", file=sys.stderr)
            return False
            
    except Exception as e:
        print(f"Error modifying config.yaml: {e}", file=sys.stderr)
        return False

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: update_config.py <config.yaml> <key_path> <new_value>", file=sys.stderr)
        sys.exit(1)
        
    cfg_file = sys.argv[1]
    k_path = sys.argv[2]
    n_val = sys.argv[3]
    
    success = update_yaml_value(cfg_file, k_path, n_val)
    if not success:
        sys.exit(1)
