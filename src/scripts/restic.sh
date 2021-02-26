#!/usr/bin/env bash

# Requires restic: https://github.com/restic/restic
# S3 repo also requires rclone: https://downloads.rclone.org

: ${RESTIC_REPOSITORY:=${backup_dir}} #required by restic

function restic_run() {
  if ! command -v restic &> /dev/null; then
    log error "restic is not available"
    exit 1
  fi

  function _delete_old_backups() {    
    command restic forget --tag "${NEB_BACKUP_NAME}" --keep-within "${NEB_BACKUP_RETENTION}" "${@}"
  }
  function _check() {
    if ! output="$(command restic check 2>&1)"; then
      log error "Repository contains error!"
      <<<"${output}" log error
      return 1
    fi
  }

  function init() {    
    if [[ -z "${RESTIC_PASSWORD:-}" ]] \
        && [[ -z "${RESTIC_PASSWORD_FILE:-}" ]] \
        && [[ -z "${RESTIC_PASSWORD_COMMAND:-}" ]]; then
      log error "At least one of" RESTIC_PASSWORD{,_FILE,_COMMAND} "needs to be set!"
      return 1
    fi

    if output="$(command restic snapshots 2>&1 >/dev/null)"; then
      log info "Repository already initialised"
      _check
    elif <<<"${output}" grep -q '^Is there a repository at the following location?$'; then
      log info "Initialising new restic repository..."
      command restic init | log info
    elif <<<"${output}" grep -q 'wrong password'; then
      <<<"${output}" log error
      log error "Wrong password provided to an existing repository?"
      return 1
    else
      <<<"${output}" log error
      log error "Unhandled restic repository state."
      return 1
    fi    
  }
  function backup() {    
    if [[ ! -d "${data_dir}" ]]; then
      log error "${data_dir} does not exist"
      return 1
    fi    

    readarray -td, excludes_patterns < <(printf '%s' "${NEB_BACKUP_EXCLUDES}")

    excludes=()
    for pattern in "${excludes_patterns[@]}"; do
      excludes+=(--exclude "${pattern}")
    done

    log info "Backing up content in ${data_dir}"
    command restic backup --tag "${NEB_BACKUP_NAME}" "${excludes[@]}" "${data_dir}" | log info
  }
  function prune() {
    if [[ "${NEB_BACKUP_RETENTION}" == "0" ]]; then
      log_info "backup pruning disabled, set NEB_BACKUP_RETENTION to enable"
      return
    fi

    # https://github.com/restic/restic/issues/1466
    if _delete_old_backups --dry-run | grep '^remove [[:digit:]]* snapshots:$' >/dev/null; then
      log info "Forgetting snapshots older than ${NEB_BACKUP_RETENTION_DAYS}"
      _delete_old_backups --prune | log info
      _check | log info
    fi
  }
  
  function_call "${@}"
}
