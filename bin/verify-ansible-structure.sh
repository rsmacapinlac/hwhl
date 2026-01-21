#!/bin/bash
# Verification script for Ansible restructure

echo "=== Verifying Ansible Structure ==="

ERRORS=0

# Check directory structure
echo "Checking directory structure..."
for dir in ansible/inventory ansible/roles ansible/files ansible/group_vars; do
    if [ ! -d "$dir" ]; then
        echo "ERROR: Missing directory: $dir"
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ Found: $dir"
    fi
done

# Check critical files
echo -e "\nChecking critical files..."
for file in ansible/ansible.cfg ansible/site.yml; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Missing file: $file"
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ Found: $file"
    fi
done

# Check Ansible config
echo -e "\nChecking Ansible configuration..."
cd ansible || exit 1

if ansible-config dump &>/dev/null; then
    echo "✓ Ansible configuration is valid"
else
    echo "ERROR: Ansible configuration has issues"
    ERRORS=$((ERRORS + 1))
fi

# Check inventory
echo -e "\nChecking inventory..."
if ansible-inventory --list &>/dev/null; then
    echo "✓ Inventory parsing successful"
    HOST_COUNT=$(ansible-inventory --list | jq '.all.hosts | length' 2>/dev/null || echo "0")
    echo "  Found $HOST_COUNT hosts"
else
    echo "ERROR: Inventory parsing failed"
    ERRORS=$((ERRORS + 1))
fi

# Check playbook syntax
echo -e "\nChecking playbook syntax..."
for playbook in site.yml proxmox-setup.yml; do
    if [ -f "$playbook" ]; then
        if ansible-playbook "$playbook" --syntax-check &>/dev/null; then
            echo "✓ $playbook syntax valid"
        else
            echo "ERROR: $playbook syntax check failed"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Check roles
echo -e "\nChecking roles..."
ROLE_COUNT=$(find roles -maxdepth 1 -type d 2>/dev/null | wc -l)
echo "  Found $((ROLE_COUNT - 1)) roles"

# Summary
echo -e "\n=== Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All checks passed! Structure is valid."
    exit 0
else
    echo "✗ Found $ERRORS errors. Please review above."
    exit 1
fi
