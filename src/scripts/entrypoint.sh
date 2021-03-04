#!/usr/bin/env bash

function entrypoint_run() { 
  # Debugging
  if [[ "${NEB_DEBUG,,}" == "true" ]]; then
    set -o xtrace
  fi

  # REQUIRED envvar
  if [[ -z "${NEB_BACKUP_TYPE}" ]]; then
    echo "NEB_BACKUP_TYPE environment variable is required!"
    exit 1
  fi

  local -r backup_type="${NEB_BACKUP_TYPE,,}"

  ## Directories
  local -r data_dir="/usr/local/data"           # mount point
  local -r backup_dir="/usr/local/backup"       # mount point
  local -r script_dir="/opt/neb-backup"         # from build
  local -r util_dir="/opt/neb-bash"             # from github via build

  # Sources  
  . "${util_dir}/bootstrap.sh"
  . "${util_dir}/assert.sh"
  . "${util_dir}/log.sh" 
  . "${util_dir}/function.sh"

  # Assert backup file
  assert_file_exists "${script_dir}/${backup_type}.sh" "${NEB_BACKUP_TYPE} is not a valid backup type."

  # Source backup file
  . "${script_dir}/${backup_type}.sh" 

  log info "init"
  ${backup_type}_run "init"
  log info "delaying backup start..."
  sleep ${NEB_BACKUP_DELAY:-60}
  log info "backup start..."

  rcon ping

  while true; do 
    rcon say Backup starting...
    rcon save-off

    trap 'rcon save-on' EXIT

    rcon save-all

    sync
    
    ${backup_type}_run "backup"
    
    rcon save-on

    trap EXIT

    rcon say Backup Done

    ${backup_type}_run "prune"

    sleep ${NEB_BACKUP_INTERVAL:-24h}
  done  
}

entrypoint_run

#TODO restore function?
