#!/bin/bash
set -e # stops the execution if a command or pipeline has an error

function get_path_from_file() {
    local output
    output=$(dirname "$1")
    echo "$output"
}

function get_filename_from_file() {
    local output
    output=$(basename "$1")
    echo "$output"
}

function get_file_with_new_extension() {
    local file
    local extension
    local path
    local filename
    local output
    file="$1"
    extension="$2"
    path=$(get_path_from_file "$file")
    filename="$(get_filename_from_file "$file" | cut -d "." -f 1)" 
    output="$path/$filename.$extension"
    echo "$output"
}

function get_style() {
    local style_path
    style_path="$1"
    echo "!include $style_path"
}

function generate_png () {
    local file
    local path
    local filename
    file=$1
    path=$(get_path_from_file "$file")
    filename=$(get_filename_from_file "$file")

    echo "Generating new diagram image for file : $filename"

    # Copy all png files from the .puml file directory to the current directory
    # NOTE: `cp` fails if the path does not exists so we redirect stderr to /dev/null 
    #        and ignore the return code with the nop (:), otherwise the whole script fails due to the -e flag set above
    cp -f "$path"/*png ./ 2>/dev/null || :

    # Generated paths for image and temp file
    png_file=$(get_file_with_new_extension "$file" "png")
    tmp_file=$(get_file_with_new_extension "$file" "tmp")

    # Add styling to puml tmp file
    head -n 1 "$file" > "$tmp_file"
    if [ "$style_path" != "" ]; then
        get_style "$style_path" >> "$tmp_file"
    fi
    sed 1d "$file" >> "$tmp_file"

    # Generate the png file from temporary generated file
    cat "$tmp_file" | java -DPLANTUML_LIMIT_SIZE=100000000 -jar /opt/plantuml.jar -pipe > "$png_file"

    # Remove all png files that were copied before the diagram generation
    rm -f ./*png
    # Remove tmp file
    rm -f "$tmp_file"
}

function find_and_generate() {
    local default_branch
    local last_commit_default_branch
    local last_commit_branch
    local changed_files
    
    # discover default branch
    default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}'); 
    # get hash of last commit on default branch
    last_commit_default_branch=$(git log -1 remotes/origin/"$default_branch" --pretty=format:'%H')
    #get hash of last commit on current branch
    last_commit_branch=$(git log -1 --pretty=format:'%H')
    echo "default branch: $default_branch, HEAD of default branch: $last_commit_default_branch, HEAD of current branch: $last_commit_branch"
   
    # get changed plant UML files
    changed_files=$(git diff --dirstat "$last_commit_default_branch" "$last_commit_branch" --name-only | grep -E "\.puml\"?$")
    echo -e "List of changed files:\n$changed_files"
    for file in $changed_files
    do
        generate_png "$file"
    done
}

#################
#      main     #
#################
style_path=$1
if [ "$style_path" != "" ]; then
    echo "style_path: $style_path"
fi

cd /github/workspace/

git config core.quotepath off

find_and_generate
