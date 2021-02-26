#!/usr/bin/env bash

function tar_run() {
  local -r backup_extension="tgz"

  _find_old_backups() {
    local retention=${NEB_BACKUP_RETENTION,,}
    local t="${retention: -1}"
    local scope="-mtime"

    [[ "${t}" == "m" ]] && scope="-mmin"

    case "${t}" in
      [!0-9]) 
        retention="${retention::-1}"
      ;;
      *) ;;
    esac    

    find "${backup_dir}" -maxdepth 1 -name "*.${backup_extension}" "${scope}" "+${retention}" "${@}"
  }

  function init() {
    mkdir -p "${backup_dir}"    
  }
  function backup() {    
    ts=$(date -u +"%Y%m%d-%H%M%S")
    outFile="${backup_dir}/${NEB_BACKUP_NAME}-${ts}.${backup_extension}"
    log info "Backing up content in ${data_dir} to ${outFile}"

    # TODO move to array??
    readarray -td, excludes_patterns < <(printf '%s' "${NEB_BACKUP_EXCLUDES}")
    excludes=()
    for pattern in "${excludes_patterns[@]}"; do
      excludes+=(--exclude "${pattern}")
    done

    command tar "${excludes[@]}" -czf "${outFile}" -C "${data_dir}" .    
    # ln -sf "${BACKUP_NAME}-${ts}.${backup_extension}" "${backup_dir}/latest.${backup_extension}"    
  }
  function prune() {
    if [ -n "$(_find_old_backups -print -quit)" ]; then
      # TODO improve message
      log info "Pruning backup files within time: ${NEB_BACKUP_RETENTION}"
      _find_old_backups -print -delete | awk '{ printf "Removing %s\n", $0 }' | log info
    fi
  }

  function_call "${@}"
}

# init, backup, prune
function backup_exec() {
  case "${BACKUP_TYPE^^}" in
    TAR)
      backup_tar "${@}"
    ;;
    RESTIC)
      if ! command -v restic &> /dev/null; then
        log error "restic is not available"
        return 1
      fi
      backup_restic "${@}"
    ;;
    *)
      log error "backup type ${backup_type} does not exist"
  esac
}