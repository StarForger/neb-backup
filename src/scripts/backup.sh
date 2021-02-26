#!/usr/bin/env bash

# Requires restic: https://github.com/restic/restic
# S3 repo also requires rclone: https://downloads.rclone.org

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${dir}/log.sh"
source "${dir}/function.sh"

: ${BACKUP_TYPE:="tar"}
: ${BACKUP_NAME:="neb-backup"}
: ${BACKUP_DIR:="/srv/restic-repo"}
: ${BACKUP_RETENTION_DAYS:=7}
: ${BACKUP_EXCLUDES:=*.jar,cache,logs}

: ${RESTIC_REPOSITORY:=${BACKUP_DIR}} #required by restic

function backup_restic() {
  function _delete_old_backups() {    
    command restic forget --tag "${BACKUP_NAME}" --keep-within "${BACKUP_RETENTION_DAYS}d" "${@}"
  }
  function _check() {
    if ! output="$(command restic check 2>&1)"; then
      log error "Repository contains error!"
      <<<"${output}" log error
      return 1
    fi
  }

  function init() {    
    if [ -z "${RESTIC_PASSWORD:-}" ] \
        && [ -z "${RESTIC_PASSWORD_FILE:-}" ] \
        && [ -z "${RESTIC_PASSWORD_COMMAND:-}" ]; then
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
    local -r src_dir="${1}"
    if [[ ! -d "${src_dir}" ]]; then
      log error "${src_dir} does not exist"
      return 1
    fi    

    readarray -td, excludes_patterns < <(printf '%s' "${BACKUP_EXCLUDES}")

    excludes=()
    for pattern in "${excludes_patterns[@]}"; do
      excludes+=(--exclude "${pattern}")
    done

    log info "Backing up content in ${src_dir}"
    command restic backup --tag "${BACKUP_NAME}" "${excludes[@]}" "${src_dir}" | log info
  }
  function prune() {
    if (( "${BACKUP_RETENTION_DAYS}" <= 0 )); then
      log_info "backup pruning disabled, set BACKUP_RETENTION_DAYS to enable"
      return
    fi

    # We cannot use `grep -q` here - see https://github.com/restic/restic/issues/1466
    if _delete_old_backups --dry-run | grep '^remove [[:digit:]]* snapshots:$' >/dev/null; then
      log info "Forgetting snapshots older than ${BACKUP_RETENTION_DAYS} days"
      _delete_old_backups --prune | log info
      _check | log info
    fi
  }
  
  function_call "${@}"
}

function backup_tar() {
  local -r backup_extension="tgz"
  _find_old_backups() {
    find "${BACKUP_DIR}" -maxdepth 1 -name "*.${backup_extension}" -mtime "+${BACKUP_RETENTION_DAYS}" "${@}"
  }

  function init() {
    mkdir -p "${BACKUP_DIR}"    
  }
  function backup() {
    local -r src_dir="${1}"
    ts=$(date -u +"%Y%m%d-%H%M%S")
    outFile="${BACKUP_DIR}/${BACKUP_NAME}-${ts}.${backup_extension}"
    log info "Backing up content in ${src_dir} to ${outFile}"

    # TODO move to array??
    readarray -td, excludes_patterns < <(printf '%s' "${BACKUP_EXCLUDES}")
    excludes=()
    for pattern in "${excludes_patterns[@]}"; do
      excludes+=(--exclude "${pattern}")
    done

    command tar "${excludes[@]}" -czf "${outFile}" -C "${src_dir}" .    
    # ln -sf "${BACKUP_NAME}-${ts}.${backup_extension}" "${BACKUP_DIR}/latest.${backup_extension}"    
  }
  function prune() {
    if [ -n "$(_find_old_backups -print -quit)" ]; then
      log info "Pruning backup files older than ${BACKUP_RETENTION_DAYS} days"
      _find_old_backups -print -delete | awk '{ printf "Removing %s\n", $0 }' | log INFO
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

#TODO select tar or restic
#TODO restore function
