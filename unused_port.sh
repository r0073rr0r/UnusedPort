#!/bin/bash

# Exit on undefined variables (but allow command failures for grep, etc. since they're expected)
# Note: We use 'set -u' instead of 'set -eu' because grep/lsof failures when ports aren't found are expected,
# not errors. Individual functions handle their own error checking.
set -u

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
MAX_JOBS=50
PORT_CHECK_TIMEOUT=2

# Defaults (can be overridden by command line options)
PORT_CHECKER_DEFAULT="ss"  # ss or lsof
FIREWALL_TOOL_DEFAULT="ufw"  # ufw or iptables

# Cleanup function for temp directory
cleanup() {
  if [[ -n "${temp_dir:-}" ]] && [[ -d "$temp_dir" ]]; then
    rm -rf "$temp_dir" 2>/dev/null || true
  fi
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Check if required commands exist
check_dependencies() {
  local missing_deps=()
  
  # Check firewall tool
  if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
    if ! command -v ufw &>/dev/null; then
      echo -e "${RED}Error: ufw is not installed or not in PATH${NC}" >&2
      exit 1
    fi
  elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
    if ! command -v iptables &>/dev/null; then
      echo -e "${RED}Error: iptables is not installed or not in PATH${NC}" >&2
      exit 1
    fi
    # iptables requires root for listing rules
    if [[ $EUID -ne 0 ]]; then
      echo -e "${RED}Error: Root privileges required to read iptables rules${NC}" >&2
      exit 1
    fi
  fi
  
  # Check port checker tool
  if [[ "$PORT_CHECKER" == "ss" ]]; then
    if ! command -v ss &>/dev/null; then
      echo -e "${RED}Error: ss is not installed or not in PATH${NC}" >&2
      exit 1
    fi
  elif [[ "$PORT_CHECKER" == "lsof" ]]; then
    if ! command -v lsof &>/dev/null; then
      echo -e "${RED}Error: lsof is not installed or not in PATH${NC}" >&2
      exit 1
    fi
  fi
}

# Validate port number
validate_port() {
  local port="$1"
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  if (( port < 1 || port > 65535 )); then
    return 1
  fi
  return 0
}

# Check if port is in use (faster with ss, fallback to lsof)
check_port_in_use() {
  local port="$1"
  
  # Check if port is in use - use || true to prevent set -e from exiting when grep doesn't find a match
  if [[ "$PORT_CHECKER" == "ss" ]]; then
    # ss is faster - check both TCP and UDP listeners
    timeout "$PORT_CHECK_TIMEOUT" ss -lntu 2>/dev/null | grep -q ":$port " || return 1
    return 0
  else
    # Fallback to lsof
    timeout "$PORT_CHECK_TIMEOUT" lsof -i ":$port" &>/dev/null || return 1
    return 0
  fi
}

# Check if firewall is active
check_firewall_active() {
  if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
    # Check if UFW is active - handle grep failure gracefully with || true
    ufw status 2>/dev/null | grep -q "Status: active" || {
      echo -e "${YELLOW}Warning: UFW is not active. Results may be inaccurate.${NC}" >&2
      true  # Prevent set -e from exiting
    }
  elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
    # iptables is always "active" if we can read it, but check if there are any rules
    iptables -L -n 2>/dev/null | grep -q -v "^Chain\|^target\|^$" || {
      echo -e "${YELLOW}Warning: No iptables rules found.${NC}" >&2
      true  # Prevent set -e from exiting
    }
  fi
}

# Help function
show_help() {
  echo -e "${BOLD}${BLUE}Usage:${NC} $0 [OPTIONS]"
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -p, --port PORT      Check a specific port number"
  echo "  -r, --remove         Remove unused ports from firewall (requires confirmation)"
  echo "  -d, --dry-run        Show what would be removed without actually removing"
  echo "  -y, --yes            Skip confirmation prompt (use with --remove)"
  echo "  --force               Skip backup creation when removing (not recommended)"
  echo "  --restore [FILE]      Restore firewall rules from the last backup (or from FILE if provided)"
  echo "  --restore-from FILE   Restore firewall rules from a specific backup file"
  echo "  --rrstore             Restore firewall rules from the last backup (alias for --restore)"
  echo "  --rrstore-from FILE   Restore firewall rules from a specific backup file (alias for --restore-from)"
  echo "  --list-backups        List all available backup files"
  echo "  --show-last-backup    Show the path to the last backup file"
  echo "  --ss                  Use 'ss' for port checking (default)"
  echo "  --lsof                Use 'lsof' for port checking"
  echo "  --ufw                 Use UFW firewall (default)"
  echo "  --iptables            Use iptables firewall"
  echo "  -h, --help            Show this help message"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  $0                      # Check all UFW ports using ss"
  echo "  $0 -p 8080              # Check port 8080"
  echo "  $0 --iptables           # Check iptables ports"
  echo "  $0 --lsof --ufw         # Use lsof with UFW"
  echo "  $0 --dry-run            # Preview unused ports that would be removed"
  echo "  $0 --remove             # Remove unused ports (with backup and confirmation)"
  echo "  $0 --remove --yes       # Remove unused ports with backup, no confirmation"
  echo "  $0 --remove --force     # Remove unused ports without backup (not recommended)"
  echo "  $0 --restore            # Restore firewall rules from last backup"
  echo "  $0 --restore FILE      # Restore firewall rules from specific backup file"
  echo "  $0 --restore-from FILE # Restore firewall rules from specific backup file"
  echo "  $0 --rrstore            # Restore firewall rules from last backup (alias)"
  echo "  $0 --rrstore-from FILE # Restore firewall rules from specific backup file (alias)"
  echo "  $0 --list-backups       # List all available backup files"
  echo "  $0 --show-last-backup   # Show path to the last backup file"
  echo ""
  echo -e "${BOLD}Description:${NC}"
  echo "  This script checks which ports from firewall rules (UFW or iptables) are not"
  echo "  currently in use. It can check all firewall ports, check a specific port,"
  echo "  or remove unused ports. Uses 'ss' by default for port checking (faster than lsof)."
  echo ""
  echo -e "${BOLD}${YELLOW}Warning:${NC} Removing firewall rules can affect security and connectivity."
  echo "  Always review what will be removed before confirming."
  echo "  Note: iptables requires root privileges to read rules."
  echo ""
  echo -e "${BOLD}Backup and Restore:${NC}"
  echo "  By default, a backup is created before removing rules. Use --force to skip backup."
  echo "  Use --restore or --rrstore to restore rules from the last backup if deleted by mistake."
  echo "  Use --restore-from FILE or --rrstore-from FILE to restore from a specific backup file (useful if symlink is broken)."
}

# Parse command line arguments
REMOVE_MODE=false
DRY_RUN=false
SKIP_CONFIRM=false
SKIP_BACKUP=false
RESTORE_MODE=false
RESTORE_FROM_FILE=""
LIST_BACKUPS=false
SHOW_LAST_BACKUP=false
SPECIFIC_PORT=""
PORT_CHECKER="$PORT_CHECKER_DEFAULT"
FIREWALL_TOOL="$FIREWALL_TOOL_DEFAULT"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -p|--port)
      if [[ -z "$2" ]]; then
        echo -e "${RED}Error: Port number required after -p/--port${NC}" >&2
        echo "Use -h or --help for usage information"
        exit 1
      fi
      SPECIFIC_PORT="$2"
      shift
      ;;
    -r|--remove)
      REMOVE_MODE=true
      ;;
    -d|--dry-run)
      DRY_RUN=true
      ;;
    -y|--yes)
      SKIP_CONFIRM=true
      ;;
    --force)
      SKIP_BACKUP=true
      ;;
    --restore|--rrstore)
      RESTORE_MODE=true
      # Check if next argument is a file (doesn't start with -)
      if [[ -n "$2" ]] && [[ ! "$2" =~ ^- ]]; then
        RESTORE_FROM_FILE="$2"
        shift
      fi
      ;;
    --restore-from|--rrstore-from)
      if [[ -z "$2" ]]; then
        echo -e "${RED}Error: Backup file path required after $1${NC}" >&2
        echo "Use -h or --help for usage information"
        exit 1
      fi
      RESTORE_MODE=true
      RESTORE_FROM_FILE="$2"
      shift
      ;;
    --list-backups)
      LIST_BACKUPS=true
      ;;
    --show-last-backup)
      SHOW_LAST_BACKUP=true
      ;;
    --ss)
      PORT_CHECKER="ss"
      ;;
    --lsof)
      PORT_CHECKER="lsof"
      ;;
    --ufw)
      FIREWALL_TOOL="ufw"
      ;;
    --iptables)
      FIREWALL_TOOL="iptables"
      ;;
    *)
      echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
  shift
done

# Initialize dependencies
check_dependencies

# Get backup file path
get_backup_file() {
  local backup_dir="${HOME}/.unused_port_backups"
  mkdir -p "$backup_dir" 2>/dev/null || {
    backup_dir="/tmp/unused_port_backups"
    mkdir -p "$backup_dir" 2>/dev/null || {
      echo -e "${RED}Error: Cannot create backup directory${NC}" >&2
      return 1
    }
  }
  echo "${backup_dir}/firewall_backup_${FIREWALL_TOOL}_$(date +%Y%m%d_%H%M%S).txt"
}

# Create backup of firewall rules
create_backup() {
  local backup_file="$1"
  
  echo -e "${BOLD}${BLUE}Creating backup...${NC}"
  
  if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
    # Backup UFW rules
    ufw status numbered > "$backup_file" 2>/dev/null || {
      echo -e "${RED}Error: Failed to create UFW backup${NC}" >&2
      return 1
    }
  elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
    # Backup iptables rules
    {
      echo "# iptables backup created on $(date)"
      echo "# Firewall tool: $FIREWALL_TOOL"
      iptables-save
    } > "$backup_file" 2>/dev/null || {
      echo -e "${RED}Error: Failed to create iptables backup${NC}" >&2
      return 1
    }
  fi
  
  echo -e "${GREEN}✓ Backup created: $backup_file${NC}"
  # Also create a symlink to the latest backup for easy restore
  local latest_backup="${backup_file%/*}/latest_${FIREWALL_TOOL}_backup.txt"
  ln -sf "$(basename "$backup_file")" "$latest_backup" 2>/dev/null || true
  return 0
}

# Restore firewall rules from backup
restore_from_backup() {
  # Check for root privileges
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: Root privileges required to restore firewall rules.${NC}" >&2
    echo -e "${YELLOW}Please run with sudo or as root.${NC}" >&2
    exit 1
  fi
  
  local backup_dir="${HOME}/.unused_port_backups"
  [[ ! -d "$backup_dir" ]] && backup_dir="/tmp/unused_port_backups"
  
  local backup_file=""
  
  # If a specific file was provided, use it
  if [[ -n "$RESTORE_FROM_FILE" ]]; then
    # Check if it's an absolute path
    if [[ "$RESTORE_FROM_FILE" =~ ^/ ]]; then
      backup_file="$RESTORE_FROM_FILE"
    else
      # Relative path - check in backup directory first, then current directory
      if [[ -f "${backup_dir}/${RESTORE_FROM_FILE}" ]]; then
        backup_file="${backup_dir}/${RESTORE_FROM_FILE}"
      elif [[ -f "$RESTORE_FROM_FILE" ]]; then
        backup_file="$RESTORE_FROM_FILE"
      else
        echo -e "${RED}Error: Backup file not found: $RESTORE_FROM_FILE${NC}" >&2
        echo -e "${YELLOW}Available backups in $backup_dir:${NC}"
        ls -lh "${backup_dir}"/firewall_backup_*.txt 2>/dev/null || echo "  (none)"
        exit 1
      fi
    fi
    
    if [[ ! -f "$backup_file" ]]; then
      echo -e "${RED}Error: Backup file does not exist: $backup_file${NC}" >&2
      exit 1
    fi
  else
    # Use latest backup logic
    if [[ ! -d "$backup_dir" ]]; then
      echo -e "${RED}Error: No backup directory found.${NC}" >&2
      exit 1
    fi
    
    # Find the latest backup for the current firewall tool
    local latest_backup="${backup_dir}/latest_${FIREWALL_TOOL}_backup.txt"
    
    if [[ -L "$latest_backup" ]] && [[ -f "$latest_backup" ]]; then
      backup_file="$(readlink -f "$latest_backup")"
      # If symlink is broken, try to find the actual file
      if [[ ! -f "$backup_file" ]]; then
        echo -e "${YELLOW}Warning: Symlink '$latest_backup' is broken, searching for latest backup...${NC}" >&2
        backup_file=$(ls -t "${backup_dir}"/firewall_backup_${FIREWALL_TOOL}_*.txt 2>/dev/null | head -1)
      fi
    else
      # Find the most recent backup file
      backup_file=$(ls -t "${backup_dir}"/firewall_backup_${FIREWALL_TOOL}_*.txt 2>/dev/null | head -1)
    fi
    
    if [[ -z "$backup_file" ]] || [[ ! -f "$backup_file" ]]; then
      echo -e "${RED}Error: No backup file found for $FIREWALL_TOOL.${NC}" >&2
      echo -e "${YELLOW}Available backups in $backup_dir:${NC}"
      ls -lh "${backup_dir}"/firewall_backup_*.txt 2>/dev/null || echo "  (none)"
      exit 1
    fi
  fi
  
  # Display backup file information
  echo -e "${BOLD}${BLUE}Backup file information:${NC}"
  echo -e "${BOLD}File:${NC} $backup_file"
  
  # Show file details
  if [[ -f "$backup_file" ]]; then
    local size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
    local date_str=$(stat -c "%y" "$backup_file" 2>/dev/null || stat -f "%Sm" "$backup_file" 2>/dev/null || echo "unknown")
    echo -e "${BOLD}Size:${NC} $size"
    echo -e "${BOLD}Modified:${NC} $date_str"
  fi
  echo ""
  
  # Show preview of what will be restored (first few lines for UFW)
  if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
    local rule_count=$(tail -n +4 "$backup_file" 2>/dev/null | grep -c "^\[" || echo "0")
    echo -e "${BOLD}${BLUE}Preview of backup file (showing first 5 rules):${NC}"
    tail -n +4 "$backup_file" 2>/dev/null | head -5 | sed 's/^/  /'
    if [[ $rule_count -gt 5 ]]; then
      echo -e "${YELLOW}  ... and $((rule_count - 5)) more rule(s)${NC}"
    fi
    echo ""
    echo -e "${BOLD}Total rules in backup:${NC} $rule_count"
  elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
    echo -e "${BOLD}${BLUE}Backup file contains iptables rules (iptables-save format)${NC}"
  fi
  echo ""
  
  # Confirmation prompt
  echo -e "${BOLD}${YELLOW}Restoring firewall rules from: $backup_file${NC}"
  echo -e "${BOLD}${RED}WARNING: This will restore firewall rules from the backup.${NC}"
  echo -e "${BOLD}Are you sure you want to continue? (yes/no):${NC} "
  read -r confirmation
  if [[ "$confirmation" != "yes" ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
  fi
  
  echo ""
  echo -e "${BOLD}${BLUE}Restoring rules...${NC}"
  
  if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
    # Restore UFW rules
    # Parse the backup file and restore rules
    local restored_count=0
    local failed_count=0
    
    while IFS= read -r line; do
      # Extract rule from backup (format: [ N] PORT ACTION DIRECTION SOURCE)
      if [[ $line =~ ^\[[[:space:]]*([0-9]+)\][[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$ ]]; then
        local port_spec="${BASH_REMATCH[2]}"
        local action="${BASH_REMATCH[3]}"
        local direction="${BASH_REMATCH[4]}"
        local source="${BASH_REMATCH[5]}"
        
        # Skip header lines
        [[ "$port_spec" == "--" ]] && continue
        
        # Build ufw command
        action_lower=$(echo "$action" | tr '[:upper:]' '[:lower:]')
        
        # Check if rule already exists
        if ufw status | grep -q "^${port_spec}[[:space:]]"; then
          echo -e "${YELLOW}⊘ Rule already exists: $port_spec $action $direction${NC}"
          continue
        fi
        
        # Add the rule
        if [[ "$direction" == "OUT" ]]; then
          if ufw "$action_lower" out "$port_spec" &>/dev/null; then
            echo -e "${GREEN}✓ Restored: $port_spec $action $direction${NC}"
            ((restored_count++))
          else
            echo -e "${RED}✗ Failed to restore: $port_spec $action $direction${NC}"
            ((failed_count++))
          fi
        else
          if ufw "$action_lower" "$port_spec" &>/dev/null; then
            echo -e "${GREEN}✓ Restored: $port_spec $action $direction${NC}"
            ((restored_count++))
          else
            echo -e "${RED}✗ Failed to restore: $port_spec $action $direction${NC}"
            ((failed_count++))
          fi
        fi
      fi
    done < <(tail -n +4 "$backup_file")
    
    echo ""
    if [[ $failed_count -eq 0 ]]; then
      echo -e "${BOLD}${GREEN}Successfully restored $restored_count rule(s).${NC}"
    else
      echo -e "${BOLD}${YELLOW}Restored $restored_count rule(s), $failed_count failed.${NC}"
    fi
    
  elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
    # Restore iptables rules
    if iptables-restore < "$backup_file" 2>/dev/null; then
      echo -e "${GREEN}✓ Successfully restored iptables rules from backup${NC}"
    else
      echo -e "${RED}✗ Failed to restore iptables rules${NC}" >&2
      exit 1
    fi
  fi
  
  exit 0
}

# Function to list available backup files
list_backup_files() {
  local backup_dir="${HOME}/.unused_port_backups"
  [[ ! -d "$backup_dir" ]] && backup_dir="/tmp/unused_port_backups"
  
  if [[ ! -d "$backup_dir" ]]; then
    echo -e "${YELLOW}No backup directory found.${NC}"
    echo -e "${YELLOW}Backups are created when removing firewall rules.${NC}"
    exit 0
  fi
  
  echo -e "${BOLD}${BLUE}Available backup files for $FIREWALL_TOOL:${NC}"
  echo ""
  
  local backups=()
  while IFS= read -r -d '' file; do
    backups+=("$file")
  done < <(find "$backup_dir" -name "firewall_backup_${FIREWALL_TOOL}_*.txt" -type f -print0 2>/dev/null | sort -z)
  
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No backup files found for $FIREWALL_TOOL.${NC}"
    exit 0
  fi
  
  # Show backups with details
  for backup in "${backups[@]}"; do
    local filename=$(basename "$backup")
    local size=$(du -h "$backup" 2>/dev/null | cut -f1)
    local date_str=$(stat -c "%y" "$backup" 2>/dev/null || stat -f "%Sm" "$backup" 2>/dev/null || echo "unknown")
    
    # Check if this is the latest backup
    local latest_backup="${backup_dir}/latest_${FIREWALL_TOOL}_backup.txt"
    local is_latest=""
    if [[ -L "$latest_backup" ]]; then
      local linked_file=$(readlink -f "$latest_backup" 2>/dev/null)
      if [[ "$linked_file" == "$backup" ]]; then
        is_latest="${GREEN}[LATEST]${NC} "
      fi
    fi
    
    echo -e "  ${is_latest}${BLUE}$backup${NC}"
    echo -e "    Size: $size | Modified: $date_str"
    echo ""
  done
  
  echo -e "${BOLD}To restore from a backup, use:${NC}"
  echo -e "  $0 --restore                    # Restore from latest backup"
  echo -e "  $0 --restore-from <filename>    # Restore from specific backup"
  exit 0
}

# Function to show the last backup file path
show_last_backup() {
  local backup_dir="${HOME}/.unused_port_backups"
  [[ ! -d "$backup_dir" ]] && backup_dir="/tmp/unused_port_backups"
  
  if [[ ! -d "$backup_dir" ]]; then
    echo -e "${YELLOW}No backup directory found.${NC}"
    exit 1
  fi
  
  local latest_backup="${backup_dir}/latest_${FIREWALL_TOOL}_backup.txt"
  local backup_file=""
  
  if [[ -L "$latest_backup" ]] && [[ -f "$latest_backup" ]]; then
    backup_file="$(readlink -f "$latest_backup")"
    # If symlink is broken, try to find the actual file
    if [[ ! -f "$backup_file" ]]; then
      backup_file=$(ls -t "${backup_dir}"/firewall_backup_${FIREWALL_TOOL}_*.txt 2>/dev/null | head -1)
    fi
  else
    # Find the most recent backup file
    backup_file=$(ls -t "${backup_dir}"/firewall_backup_${FIREWALL_TOOL}_*.txt 2>/dev/null | head -1)
  fi
  
  if [[ -z "$backup_file" ]] || [[ ! -f "$backup_file" ]]; then
    echo -e "${RED}No backup file found for $FIREWALL_TOOL.${NC}" >&2
    exit 1
  fi
  
  echo -e "${BOLD}${GREEN}Last backup file:${NC}"
  echo -e "${BLUE}$backup_file${NC}"
  
  # Show file details
  if [[ -f "$backup_file" ]]; then
    local size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
    local date_str=$(stat -c "%y" "$backup_file" 2>/dev/null || stat -f "%Sm" "$backup_file" 2>/dev/null || echo "unknown")
    echo -e "${BOLD}Size:${NC} $size"
    echo -e "${BOLD}Modified:${NC} $date_str"
    echo ""
    echo -e "${BOLD}To restore from this backup, run:${NC}"
    echo -e "  $0 --restore"
    echo ""
    echo -e "${BOLD}Or restore from this specific file:${NC}"
    echo -e "  $0 --restore-from $(basename "$backup_file")"
  fi
  
  exit 0
}

# Handle list backups mode early
if [[ "$LIST_BACKUPS" == true ]]; then
  list_backup_files
fi

# Handle show last backup mode early
if [[ "$SHOW_LAST_BACKUP" == true ]]; then
  show_last_backup
fi

# Handle restore mode early
if [[ "$RESTORE_MODE" == true ]]; then
  restore_from_backup
fi

# Check for specific port argument
if [[ -n "$SPECIFIC_PORT" ]]; then
  port="$SPECIFIC_PORT"
  if ! validate_port "$port"; then
    echo -e "${RED}Error: Invalid port number '$port' (must be 1-65535)${NC}" >&2
    exit 1
  fi
  
  echo -e "${BOLD}${BLUE}Checking port:${NC} $port"
  echo ""
  
  if ! check_port_in_use "$port"; then
    echo -e "${GREEN}✓ Port $port is ${BOLD}NOT IN USE${NC}"
    exit 0
  else
    echo -e "${RED}✗ Port $port is ${BOLD}IN USE${NC}"
    echo ""
    echo -e "${YELLOW}Processes using port $port:${NC}"
    if [[ "$PORT_CHECKER" == "ss" ]]; then
      ss -lntup | grep ":$port " || true
    else
      lsof -i ":$port" || true
    fi
    exit 1
  fi
fi

# Get firewall status
if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
  echo -e "${BOLD}${BLUE}Checking UFW ports (using $PORT_CHECKER)...${NC}"
elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
  echo -e "${BOLD}${BLUE}Checking iptables ports (using $PORT_CHECKER)...${NC}"
fi
echo ""

# Check if firewall is active
check_firewall_active

# Arrays to store all ports and their rule specifications
declare -a all_ports=()
declare -a all_rule_numbers=()
declare -a all_port_specs=()
declare -a all_actions=()
declare -a all_directions=()
declare -a all_sources=()

# Arrays to store unused ports and their rule specifications
declare -a unused_ports=()
declare -a unused_rule_numbers=()
declare -a unused_port_specs=()
declare -a unused_actions=()
declare -a unused_directions=()
declare -a unused_sources=()

# Parse firewall rules based on selected tool
if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
  # Parse UFW status numbered output
  # Format: [ 1] 1194                       ALLOW IN    Anywhere
  firewall_output=$(ufw status numbered 2>/dev/null || {
    echo -e "${RED}Error: Failed to get UFW status. Is UFW installed and accessible?${NC}" >&2
    exit 1
  })
  
  rule_counter=0
  while IFS= read -r line; do
    # Extract rule number (e.g., [ 1] -> 1)
    if [[ $line =~ ^\[[[:space:]]*([0-9]+)\][[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$ ]]; then
      rule_num="${BASH_REMATCH[1]}"
      port_spec="${BASH_REMATCH[2]}"
      action="${BASH_REMATCH[3]}"
      direction="${BASH_REMATCH[4]}"
      source="${BASH_REMATCH[5]}"
      
      # Extract port number (handle cases like "3478/tcp" -> "3478")
      # Use || true to handle awk errors gracefully (though awk shouldn't fail here)
      port=$(echo "$port_spec" | awk '{split($1, a, "/"); print a[1]}' 2>/dev/null || echo "")
      
      # Validate and skip invalid ports
      if [[ -z "$port" ]] || [[ "$port" =~ : ]] || ! validate_port "$port"; then
        continue
      fi
      
      # Store all valid ports for parallel checking
      all_ports+=("$port")
      all_rule_numbers+=("$rule_num")
      all_port_specs+=("$port_spec")
      all_actions+=("$action")
      all_directions+=("$direction")
      all_sources+=("$source")
      ((rule_counter++))
    fi
  done < <(echo "$firewall_output" | tail -n +4)
  
elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
  # Parse iptables rules
  # Format: Chain INPUT (policy ACCEPT), then rules like:
  # ACCEPT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:8080
  firewall_output=$(iptables -L -n -v --line-numbers 2>/dev/null || {
    echo -e "${RED}Error: Failed to get iptables rules. Is iptables accessible?${NC}" >&2
    exit 1
  })
  
  current_chain=""
  rule_counter=0
  
  while IFS= read -r line; do
    # Detect chain header (e.g., "Chain INPUT (policy ACCEPT)")
    if [[ $line =~ ^Chain[[:space:]]+([A-Z]+)[[:space:]]+\( ]]; then
      current_chain="${BASH_REMATCH[1]}"
      continue
    fi
    
    # Skip header lines and empty lines
    if [[ $line =~ ^(num|pkts|target|Chain) ]] || [[ -z "$line" ]]; then
      continue
    fi
    
    # Parse rule line
    # Format: num pkts bytes target prot opt in out source destination [options]
    # Example: 5 0 0 ACCEPT tcp -- * * 0.0.0.0/0 0.0.0.0/0 tcp dpt:8080
    if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([A-Z]+)[[:space:]]+([a-z]+)[[:space:]]+ ]]; then
      rule_num="${BASH_REMATCH[1]}"
      action="${BASH_REMATCH[2]}"
      protocol="${BASH_REMATCH[3]}"
      
      # Extract port from rule (look for dpt:PORT or spt:PORT)
      # Prefer destination port (dpt) over source port (spt) as it's more common
      port=""
      port_spec=""
      
      # Check for destination port (dpt:PORT) - most common case
      if [[ $line =~ dpt:([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
        port_spec="${port}/${protocol}"
      # Check for source port (spt:PORT) - less common
      elif [[ $line =~ spt:([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
        port_spec="${port}/${protocol}"
      # Check for multiport (dports or sports)
      elif [[ $line =~ (dports|sports):([0-9]+) ]]; then
        port="${BASH_REMATCH[2]}"
        port_spec="${port}/${protocol}"
      fi
      
      # Validate port
      if [[ -z "$port" ]] || ! validate_port "$port"; then
        continue
      fi
      
      # Extract source from rule (usually around position 8-9)
      source=$(echo "$line" | awk '{print $(NF-1)}' 2>/dev/null || echo "0.0.0.0/0")
      
      # Store rule information
      all_ports+=("$port")
      all_rule_numbers+=("${current_chain}:${rule_num}")
      all_port_specs+=("$port_spec")
      all_actions+=("$action")
      all_directions+=("$current_chain")
      all_sources+=("$source")
      ((rule_counter++))
    fi
  done < <(echo "$firewall_output")
fi

# Check if we have any ports to check
if [[ ${#all_ports[@]} -eq 0 ]]; then
  if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
    echo -e "${YELLOW}No valid ports found in UFW rules.${NC}"
  else
    echo -e "${YELLOW}No valid ports found in iptables rules.${NC}"
  fi
  exit 0
fi

# Check ports in parallel (limit concurrent processes to avoid overwhelming the system)
# Use separate temp files for each job to avoid write conflicts, then combine
temp_dir=$(mktemp -d) || {
  echo -e "${RED}Error: Failed to create temporary directory${NC}" >&2
  exit 1
}

job_count=0
pids=()

# Function to check a single port and write result
# This function runs in a subshell, so we need to pass the checker type
check_single_port() {
  (
    # Run in subshell to isolate set -e behavior
    set +e
    local index="$1"
    local port="$2"
    local checker="$3"
    local timeout_val="$4"
    local temp_file="$5"
    
    # Check if port is in use
    # grep returns 0 if found, 1 if not found - both are expected outcomes
    # Since we're in a subshell with set +e, command failures won't exit, but we still need to check $?
    local in_use=1
    if [[ "$checker" == "ss" ]]; then
      # Run command and capture exit code - with set +e, this won't cause exit even if grep fails
      timeout "$timeout_val" ss -lntu 2>/dev/null | grep -q ":$port " 2>/dev/null
      if [[ $? -eq 0 ]]; then
        in_use=1  # Port found, it's in use
      else
        in_use=0  # Port not found, it's not in use
      fi
    else
      timeout "$timeout_val" lsof -i ":$port" &>/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        in_use=1  # Port found, it's in use
      else
        in_use=0  # Port not found, it's not in use
      fi
    fi
    
    # If port is not in use, write index to temp file
    if [[ $in_use -eq 0 ]]; then
      echo "$index" > "$temp_file" 2>/dev/null || true
    fi
    exit 0  # Always exit successfully
  ) || true  # Ensure the function always succeeds
}

# Launch parallel port checks with deduplication
# First, identify unique ports to check
declare -A unique_ports
for i in "${!all_ports[@]}"; do
  port="${all_ports[$i]}"
  if [[ -z "${unique_ports[$port]:-}" ]]; then
    unique_ports[$port]="$i"
  fi
done

# Check unique ports in parallel
for port in "${!unique_ports[@]}"; do
  # Run port check in background
  temp_file="$temp_dir/port_$$_$port"
  # Use || true to ensure the background job launch always succeeds
  (check_single_port "${unique_ports[$port]}" "$port" "$PORT_CHECKER" "$PORT_CHECK_TIMEOUT" "$temp_file" || true) &
  pids+=($!)
  
  ((job_count++))
  # Wait when we hit the limit to avoid too many concurrent processes
  if (( job_count % MAX_JOBS == 0 )); then
    # Wait for current batch - use || true to prevent set -e from exiting
    for pid in "${pids[@]}"; do
      wait "$pid" 2>/dev/null || true
    done
    pids=()
  fi
done

# Wait for all remaining background jobs to complete
for pid in "${pids[@]}"; do
  wait "$pid" 2>/dev/null || true
done

# Read results and populate unused arrays
# For each unique port that was checked, find all rules using that port
for temp_file in "$temp_dir"/port_$$_*; do
  [[ -f "$temp_file" ]] || continue
  
  # Extract port from filename (format: port_$$_PORTNUM)
  port=$(basename "$temp_file" | sed "s/port_$$_//")
  
  # Find all indices that use this port
  for i in "${!all_ports[@]}"; do
    if [[ "${all_ports[$i]}" == "$port" ]]; then
      unused_ports+=("${all_ports[$i]}")
      unused_rule_numbers+=("${all_rule_numbers[$i]}")
      unused_port_specs+=("${all_port_specs[$i]}")
      unused_actions+=("${all_actions[$i]}")
      unused_directions+=("${all_directions[$i]}")
      unused_sources+=("${all_sources[$i]}")
    fi
  done
done

# Display results
if [[ ${#unused_ports[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No unused ports found.${NC}"
  exit 0
fi

echo -e "${BOLD}${GREEN}Unused ports (${#unused_ports[@]} total):${NC}"
echo ""
echo -e "${GREEN}$(IFS=', '; echo "${unused_ports[*]}")${NC}"
echo ""
echo -e "${BOLD}Summary:${NC} ${#unused_ports[@]} port(s) not in use"
echo ""

# Handle dry-run mode
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${BOLD}${YELLOW}DRY RUN - Rules that would be removed:${NC}"
  echo ""
  for i in "${!unused_rule_numbers[@]}"; do
    echo -e "${YELLOW}  Rule ${unused_rule_numbers[$i]}: ${unused_port_specs[$i]} ${unused_actions[$i]} ${unused_directions[$i]} ${unused_sources[$i]}${NC}"
  done
  echo ""
  echo -e "${BOLD}Run with --remove to actually remove these rules.${NC}"
  exit 0
fi

# Handle remove mode
if [[ "$REMOVE_MODE" == true ]]; then
  echo -e "${BOLD}${YELLOW}Rules to be removed:${NC}"
  echo ""
  for i in "${!unused_rule_numbers[@]}"; do
    echo -e "${YELLOW}  Rule ${unused_rule_numbers[$i]}: ${unused_port_specs[$i]} ${unused_actions[$i]} ${unused_directions[$i]} ${unused_sources[$i]}${NC}"
  done
  echo ""
  
  # Check for root privileges when removing rules
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: Root privileges required to remove firewall rules.${NC}" >&2
    echo -e "${YELLOW}Please run with sudo or as root.${NC}" >&2
    exit 1
  fi
  
  # Create backup unless --force is used
  backup_file=""
  if [[ "$SKIP_BACKUP" != true ]]; then
    backup_file=$(get_backup_file) || {
      echo -e "${RED}Error: Failed to get backup file path. Aborting removal.${NC}" >&2
      echo -e "${YELLOW}Use --force to skip backup (not recommended).${NC}" >&2
      exit 1
    }
    if ! create_backup "$backup_file"; then
      echo -e "${RED}Error: Failed to create backup. Aborting removal.${NC}" >&2
      echo -e "${YELLOW}Use --force to skip backup (not recommended).${NC}" >&2
      exit 1
    fi
    echo ""
  else
    echo -e "${YELLOW}Warning: Backup skipped (--force used). No backup will be created.${NC}"
    echo ""
  fi
  
  # Confirmation prompt
  if [[ "$SKIP_CONFIRM" != true ]]; then
    rule_count=${#unused_rule_numbers[@]}
    echo -e "${BOLD}${RED}WARNING: This will remove $rule_count firewall rule(s).${NC}"
    if [[ "$SKIP_BACKUP" != true ]]; then
      echo -e "${GREEN}Backup created: $backup_file${NC}"
      echo -e "${YELLOW}You can restore using: $0 --restore${NC}"
    fi
    echo -e "${BOLD}Are you sure you want to continue? (yes/no):${NC} "
    read -r confirmation
    if [[ "$confirmation" != "yes" ]]; then
      echo -e "${YELLOW}Operation cancelled.${NC}"
      exit 0
    fi
  fi
  
  # Remove rules by specification (not by number, to avoid renumbering issues)
  removed_count=0
  failed_count=0
  
  echo ""
  echo -e "${BOLD}${BLUE}Removing rules...${NC}"
  echo ""
  
  for i in "${!unused_rule_numbers[@]}"; do
    rule_num="${unused_rule_numbers[$i]}"
    port_spec="${unused_port_specs[$i]}"
    action="${unused_actions[$i]}"
    direction="${unused_directions[$i]}"
    
    if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
      # Sanitize inputs to prevent command injection
      # Validate action is allow or deny
      if [[ "$action" != "ALLOW" ]] && [[ "$action" != "DENY" ]]; then
        echo -e "${RED}✗ Skipping rule $rule_num: Invalid action '$action'${NC}"
        ((failed_count++))
        continue
      fi
      
      # Build delete command safely (using lowercase for ufw command)
      action_lower=$(echo "$action" | tr '[:upper:]' '[:lower:]')
      
      # Use ufw delete with proper quoting
      if ufw --force delete "$action_lower" "$port_spec" &>/dev/null; then
        echo -e "${GREEN}✓ Removed rule $rule_num: $port_spec $action${NC}"
        ((removed_count++))
      else
        echo -e "${RED}✗ Failed to remove rule $rule_num: $port_spec $action${NC}"
        ((failed_count++))
      fi
      
    elif [[ "$FIREWALL_TOOL" == "iptables" ]]; then
      # Parse chain and rule number from rule_num (format: CHAIN:NUM)
      if [[ "$rule_num" =~ ^([A-Z]+):([0-9]+)$ ]]; then
        chain="${BASH_REMATCH[1]}"
        rule_line="${BASH_REMATCH[2]}"
        
        # Extract protocol and port from port_spec (format: PORT/PROTOCOL)
        if [[ "$port_spec" =~ ^([0-9]+)/([a-z]+)$ ]]; then
          port="${BASH_REMATCH[1]}"
          protocol="${BASH_REMATCH[2]}"
          
          # Build iptables delete command
          # Format: iptables -D CHAIN RULE_NUMBER
          # Or: iptables -D CHAIN -p PROTOCOL --dport PORT -j ACTION
          if iptables -D "$chain" "$rule_line" &>/dev/null; then
            echo -e "${GREEN}✓ Removed rule $rule_num ($chain:$rule_line): $port_spec $action${NC}"
            ((removed_count++))
          else
            # Try alternative method using rule specification
            if iptables -D "$chain" -p "$protocol" --dport "$port" -j "$action" &>/dev/null; then
              echo -e "${GREEN}✓ Removed rule $rule_num ($chain): $port_spec $action${NC}"
              ((removed_count++))
            else
              echo -e "${RED}✗ Failed to remove rule $rule_num: $port_spec $action${NC}"
              ((failed_count++))
            fi
          fi
        else
          echo -e "${RED}✗ Skipping rule $rule_num: Invalid port specification '$port_spec'${NC}"
          ((failed_count++))
        fi
      else
        echo -e "${RED}✗ Skipping rule $rule_num: Invalid rule format${NC}"
        ((failed_count++))
      fi
    fi
  done
  
  echo ""
  if [[ $failed_count -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}Successfully removed $removed_count rule(s).${NC}"
  else
    echo -e "${BOLD}${YELLOW}Removed $removed_count rule(s), $failed_count failed.${NC}"
  fi
  
  # Show backup info if backup was created
  if [[ "$SKIP_BACKUP" != true ]] && [[ -n "$backup_file" ]]; then
    echo ""
    echo -e "${BOLD}${GREEN}Backup saved: $backup_file${NC}"
    echo -e "${YELLOW}To restore deleted rules, run: $0 --restore${NC}"
  fi
fi
