#!/bin/bash
set -e # stops the execution if a command or pipeline has an error

style_path=$1

function generate_png () {
    # Copy all png files from the .puml file directory to the current directory
    # NOTE: `cp` fails if the path does not exists so we redirect stderr to /dev/null 
    #        and ignore the return code with the nop (:), otherwise the whole script fails due to the -e flag set above
    cp -f ${path}/*png ./ 2>/dev/null || :

    # Generated paths for image and temp file
    png_file="$path/${filename%.*}.png"
    tmp_file="$path/${filename%.*}.tmp"
    

    head -n 1 ${file} > ${tmp_file}
    if [ "$style_path" != "" ]; then
        # Add styling to puml tmp file
        echo '!include $style_path' >> ${tmp_file}
    fi
    sed 1d ${file} >> ${tmp_file}

    # generate the png file from temporary generated file
    cat "${tmp_file}" | java -DPLANTUML_LIMIT_SIZE=100000000 -jar /opt/plantuml.jar -pipe > "${png_file}"

    # remove all png files that were copied before the diagram generation
    rm -f ./*png
    # remove tmp file
    rm -f ${tmp_file}
}

# move to the actual git repo
cd /github/workspace/

# fetch remote branchs to further validate the commit has
git fetch --all

# discover default branch
default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}'); 

# get hash of last commit on default branch
last_commit_default_branch=$(git log -1 remotes/origin/$default_branch --pretty=format:'%H')

#get hash of last commit on current branch
last_commit_branch=$(git log -1 --pretty=format:'%H')

echo "default branch: $default_branch, HEAD of default branch: $last_commit_default_branch, HEAD of current branch: $last_commit_branch"

# Get list of directories that have changes
for dir in $(git diff --dirstat $last_commit_default_branch $last_commit_branch | cut -d '%' -f 2)
do
    echo "Changes detected on folder ${dir}:"
    # get only files that end with .puml"
    for file in $(find ${dir} | grep -E "\.puml\"?$")
    do
        # separate file and path
        path=$(dirname "${file}")
        filename=$(basename "${file}")

        echo "- Generating new diagram image for file : ${filename}"
        generate_png
    done
done
