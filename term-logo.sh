#!/bin/bash

# Configuration
CONFIG_DIR="$HOME/.config/term-logos"
CONFIG_FILE="$CONFIG_DIR/config"
DEFAULT_LOGO_DIR="$HOME/Pictures/term-logos"
LOGO_DIR="${LOGO_DIR:-$DEFAULT_LOGO_DIR}"
MIN_WIDTH=10
MAX_WIDTH=18
DEFAULT_LOGO_WIDTH=14
VERBOSE=false
FLAG_FILE="$CONFIG_DIR/multi-message-shown"
FALLBACK_FLAG_FILE="$HOME/.kitty-multi-message-shown"

# Debug output function
debug() {
  [[ "$VERBOSE" == true ]] && echo "Debug: $1"
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    --logo-dir)
      if [[ -z "$2" || ! -d "$2" ]]; then
        echo "Error: --logo-dir requires a valid directory"
        exit 1
      fi
      LOGO_DIR="$2"
      shift 2
      ;;
    --fix-permissions)
      chmod u+x "$0" 2>/dev/null || echo "Warning: Failed to set script permissions"
      chmod -R u+rx "$LOGO_DIR" 2>/dev/null || echo "Warning: Failed to set permissions on '$LOGO_DIR'"
      [[ -f "$CONFIG_FILE" ]] && chmod u+r "$CONFIG_FILE" 2>/dev/null || echo "Warning: Failed to set config permissions"
      echo "Permissions fixed"
      exit 0
      ;;
    --reset-message)
      if [[ -f "$FLAG_FILE" ]]; then
        rm -f "$FLAG_FILE" 2>/dev/null && echo "Message flag reset, the message will show again next time"
      elif [[ -f "$FALLBACK_FLAG_FILE" ]]; then
        rm -f "$FALLBACK_FLAG_FILE" 2>/dev/null && echo "Message flag reset, the message will show again next time"
      else
        echo "No message flag found, nothing to reset"
      fi
      exit 0
      ;;
    *) echo "Error: Unknown option: $1"; exit 1 ;;
  esac
done

# Validate environment
debug "HOME: $HOME"
debug "USER: $USER"
if [[ -z "$HOME" ]]; then
  echo "Error: HOME variable is unset"
  exit 1
fi
if [[ -z "$USER" ]]; then
  debug "USER variable is unset, defaulting to $(whoami)"
  USER=$(whoami)
fi

# Ensure config directory exists
if [[ ! -d "$CONFIG_DIR" ]]; then
  debug "Creating config directory: $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR" 2>/dev/null
  if [[ ! -d "$CONFIG_DIR" ]]; then
    debug "Failed to create config directory '$CONFIG_DIR', using fallback flag file: $FALLBACK_FLAG_FILE"
    FLAG_FILE="$FALLBACK_FLAG_FILE"
  else
    chmod u+rwx "$CONFIG_DIR" 2>/dev/null || debug "Warning: Failed to set permissions on '$CONFIG_DIR'"
  fi
fi

# Check if script is executable
if [[ ! -x "$0" ]]; then
  debug "Script '$0' is not executable. Attempting to fix..."
  chmod u+x "$0" 2>/dev/null || { echo "Error: Failed to make script executable"; exit 1; }
fi

# Check dependencies
command -v fastfetch >/dev/null 2>&1 || { echo "Error: fastfetch not installed"; exit 1; }
command -v kitty >/dev/null 2>&1 || debug "kitty not detected, assuming terminal"

# Check config file
if [[ -f "$CONFIG_FILE" ]]; then
  debug "Loading config file: $CONFIG_FILE"
  if [[ ! -r "$CONFIG_FILE" ]]; then
    chmod u+r "$CONFIG_FILE" 2>/dev/null || { echo "Error: Failed to set permissions on '$CONFIG_FILE'"; exit 1; }
  fi
  source "$CONFIG_FILE"
  # Re-apply default if LOGO_DIR is empty after config
  LOGO_DIR="${LOGO_DIR:-$DEFAULT_LOGO_DIR}"
fi

# Resolve and validate LOGO_DIR
debug "Resolved LOGO_DIR: $LOGO_DIR"
LOGO_DIR="${LOGO_DIR/#\~/$HOME}"
if [[ -z "$LOGO_DIR" ]]; then
  echo "Error: LOGO_DIR is empty after resolution"
  exit 1
fi
if [[ ! -d "$LOGO_DIR" ]]; then
  echo "Error: Logo directory '$LOGO_DIR' does not exist"
  ls -ld "$(dirname "$LOGO_DIR")" 2>/dev/null || echo "Error: Parent directory of '$LOGO_DIR' also inaccessible"
  [[ -L "$LOGO_DIR" ]] && echo "Error: '$LOGO_DIR' is a symlink pointing to '$(readlink -f "$LOGO_DIR")'"
  echo "Would you like to create the directory '$LOGO_DIR' to store logo images? (y/N)"
  read -r -n 1 REPLY
  echo
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    mkdir -p "$LOGO_DIR" 2>/dev/null || { echo "Error: Failed to create logo directory '$LOGO_DIR'"; exit 1; }
    chmod u+rwx "$LOGO_DIR" 2>/dev/null || { echo "Error: Failed to set permissions on '$LOGO_DIR'"; exit 1; }
    echo "Directory '$LOGO_DIR' created successfully."
    echo "Please place PNG image files in '$LOGO_DIR' for use with Kitty and fastfetch."
    echo "Example: Copy PNG files to '$LOGO_DIR' using 'cp image.png $LOGO_DIR/'"
    exit 0
  else
    echo "Directory not created. Please create '$LOGO_DIR' and add PNG image files to proceed."
    exit 1
  fi
fi
if [[ ! -r "$LOGO_DIR" || ! -x "$LOGO_DIR" ]]; then
  debug "Logo directory '$LOGO_DIR' lacks read or execute permissions: $(ls -ld "$LOGO_DIR")"
  chmod -R u+rx "$LOGO_DIR" 2>/dev/null || { echo "Error: Failed to set permissions on '$LOGO_DIR'"; exit 1; }
fi

# Find logos
mapfile -t LOGOS < <(find "$LOGO_DIR" -type f -iname "*.png")
if [[ ${#LOGOS[@]} -eq 0 ]]; then
  echo "Error: No PNG files found in '$LOGO_DIR'"
  ls -l "$LOGO_DIR" 2>/dev/null
  echo "Please place PNG image files in '$LOGO_DIR' for use with Kitty and fastfetch."
  echo "Example: Copy PNG files to '$LOGO_DIR' using 'cp image.png $LOGO_DIR/'"
  exit 1
fi
for logo in "${LOGOS[@]}"; do
  if [[ ! -r "$logo" ]]; then
    debug "Logo file '$logo' is not readable"
    chmod u+r "$logo" 2>/dev/null || { echo "Error: Failed to set permissions on '$logo'"; exit 1; }
  fi
done
RANDOM_LOGO="${LOGOS[$((RANDOM % ${#LOGOS[@]}))]}"

# Get terminal width
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
LOGO_WIDTH=$(( TERM_WIDTH / 4 ))
[[ -z "$TERM_WIDTH" ]] && LOGO_WIDTH=$DEFAULT_LOGO_WIDTH

# Clamp logo width
if (( LOGO_WIDTH < MIN_WIDTH )); then
  LOGO_WIDTH=$MIN_WIDTH
elif (( LOGO_WIDTH > MAX_WIDTH )); then
  LOGO_WIDTH=$MAX_WIDTH
fi

# Check kitty windows
WINDOWS_COUNT=$(pgrep -cx kitty 2>/dev/null || echo 0)

# Verbose output
debug "Terminal width: $TERM_WIDTH"
debug "Logo width: $LOGO_WIDTH"
debug "Kitty windows: $WINDOWS_COUNT"
debug "Selected logo: $RANDOM_LOGO"
debug "Flag file: $FLAG_FILE"

# Display logic
if (( WINDOWS_COUNT <= 1 )); then
  fastfetch --logo-type kitty --logo "$RANDOM_LOGO" --logo-width "$LOGO_WIDTH"
else
  if [[ ! -f "$FLAG_FILE" ]]; then
    echo "Multiple Kitty windows are open, so the logo will not be displayed. This message will appear only once."
    touch "$FLAG_FILE" 2>/dev/null || debug "Could not create flag file '$FLAG_FILE'"
    chmod u+rw "$FLAG_FILE" 2>/dev/null || debug "Could not set permissions on '$FLAG_FILE'"
  fi
fi
