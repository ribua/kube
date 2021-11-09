#!/bin/bash 

# This script is a pre-receive hook allowing pushes whose every file:
# - is smaller than 20 M
# - and its extension is not one of the following:
#   - dll
#   - exe
#   - war
#   - ear
#   - jar
# and whose directories are not named 'node_modules'.

GITCMD="git"
NULLSHA="0000000000000000000000000000000000000000"
EMPTYTREESHA=$($GITCMD hash-object -t tree /dev/null) # SHA1: "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
MAXSIZE="20"
MAXBYTES=$(( $MAXSIZE * 1048576 ))
EXIT=0
PRIVATELOGFILE="/tmp/git_private.log"

function private_log() {
    moment=`date '+%d/%m/%Y %H:%M:%S'` 
    echo "[ $moment ] [ POLICY CHECK ] $1" >> $PRIVATELOGFILE
}

function log() {
    moment=`date '+%d/%m/%Y %H:%M:%S'` 
    echo "[ $moment ] [ POLICY CHECK ] $1"
}

log "Starting validation..." 
while read oldref newref refname; do
    
    private_log "OLDREF: $oldref NEWREF: $newref REFNAME: $refname"

    # Avoid removed branches
    if [ "${newref}" = "${NULLSHA}" ]; then
        continue
    fi

    # Set oldref properly if this is branch creation.
    if [ "${oldref}" = "${NULLSHA}" ]; then
        oldref=$EMPTYTREESHA
    fi
    
    # Ignore case
    shopt -s nocaseglob
    
    newFiles=$($GITCMD diff --stat --name-only --diff-filter=ACMRT ${oldref}..${newref})

    if [[ $? -ne 0 ]]; then 
        log "Error 101: Repository incosistency. Cancelling push..."
        exit 1;
    fi
    
    old_IFS=$IFS
    IFS='
    '    
    for filename in $newFiles; do
        private_log "Filename: $filename"
        filesize=$($GITCMD cat-file -s "${newref}:${filename}") 2> $PRIVATELOGFILE
        
        if [[ -z $filesize  ]]; then filesize=0; fi
        filesize_mb=$(($filesize / 1048576))

        if [ "${filesize}" -gt "${MAXBYTES}" ]; then
            log "File $filename is greater than $MAXSIZE MB. Its size is $filesize_mb MB."  
            exit 1
        fi
    
        if [[ "$filename" =~ "node_modules" ]]; then
            log "Folder 'node_modules' not allowed: $filename."
            exit 1
        else
            if [[ "$filename" =~ \.dll$ ]] || [[ "$filename" =~ \.exe$ ]] || [[ "$filename" =~ \.war$ ]] || [[ "$filename" =~ \.ear$ ]] || [[ "$filename" =~ \.jar$ ]]; then
                extension="${filename##*.}"
                log "Files with extension $extension not allowed. Please remove file $filename" 
                exit 1
            fi
        fi
    done
    IFS=$old_IFS
done