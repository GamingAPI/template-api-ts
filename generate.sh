#!/bin/bash
set -e

library_last_version="0.0.0"
template_last_version="0.0.0"
template_current_version="0.0.0"
document_last_version="0.0.0"
document_current_version="0.0.0"
major_template_last_version=0
minor_template_last_version=0
patch_template_last_version=0
major_template_current_version=0
minor_template_current_version=0
patch_template_current_version=0
major_version_change="false"
minor_version_change="false"
patch_version_change="false"
commit_message=""
document_last_version=$(cat ./configs.json | jq -r '.document_last_version')
template_last_version=$(cat ./configs.json | jq -r '.template_last_version')
library_last_version=$(cat ./package.json | jq -r '.version')

template_to_use="asyncapi/ts-nats-template"
template_current_version=$(curl -sL https://raw.githubusercontent.com/${template_to_use}/master/package.json | jq -r '.version' | sed 's/v//')

url_to_asyncapi_document="https://raw.githubusercontent.com/GamingAPI/definitions/main/bundled/<<[ .cus.ASYNCAPI_FILE ]>>"
document_current_version=$(curl -sL ${url_to_asyncapi_document} | jq -r '.info.version' | sed 's/v//')


# Split the last used template version by '.' to split it up into 'major.minor.fix'
semver_template_last_version=( ${template_last_version//./ } )
major_template_last_version=${semver_template_last_version[0]}
minor_template_last_version=${semver_template_last_version[1]}
patch_template_last_version=${semver_template_last_version[2]}
# Split the current template version by '.' to split it up into 'major.minor.fix'
semver_template_current_version=( ${template_current_version//./ } )
major_template_current_version=${semver_template_current_version[0]}
minor_template_current_version=${semver_template_current_version[1]}
patch_template_current_version=${semver_template_current_version[2]}
if [[ $major_template_current_version > $major_template_last_version ]]; then major_template_change="true"; else major_template_change="false"; fi
if [[ $minor_template_current_version > $minor_template_last_version ]]; then minor_template_change="true"; else minor_template_change="false"; fi
if [[ $patch_template_current_version > $patch_template_last_version ]]; then patch_template_change="true"; else patch_template_change="false"; fi

# Split the last used AsyncAPI document version by '.' to split it up into 'major.minor.fix'
semver_document_last_version=( ${document_last_version//./ } )
major_document_last_version=${semver_document_last_version[0]}
minor_document_last_version=${semver_document_last_version[1]}
patch_document_last_version=${semver_document_last_version[2]}
# Split the current AsyncAPI document version by '.' to split it up into 'major.minor.fix'
semver_document_current_version=( ${document_current_version//./ } )
major_document_current_version=${semver_document_current_version[0]}
minor_document_current_version=${semver_document_current_version[1]}
patch_document_current_version=${semver_document_current_version[2]}
if [[ $major_document_current_version > $major_document_last_version ]]; then major_document_change="true"; else major_document_change="false"; fi
if [[ $minor_document_current_version > $minor_document_last_version ]]; then minor_document_change="true"; else minor_document_change="false"; fi
if [[ $patch_document_current_version > $patch_document_last_version ]]; then patch_document_change="true"; else patch_document_change="false"; fi

# Set the commit messages that details what changed
if (($major_template_change == 'true')); then
  commit_message="Template have changed to a new major version."
elif (($minor_template_change == 'true')); then
  commit_message="Template have changed to a new minor version."
elif (($patch_template_change == 'true')); then
  commit_message="Template have changed to a new patch version."
fi
if (($major_document_change == 'true')); then
  commit_message="${commit_message}AsyncAPI document have changed to a new major version."
elif (($minor_document_change == 'true')); then
  commit_message="${commit_message}AsyncAPI document have changed to a new minor version."
elif (($patch_document_change == 'true')); then
  commit_message="${commit_message}AsyncAPI document have changed to a new patch version."
fi

# Always use the most aggressive version change, and only do one type of version change
if (($major_template_change == 'true' || $major_document_change == 'true')); then
  major_version_change="true"
elif (($minor_template_change == 'true' || $minor_document_change == 'true')); then
  minor_version_change="true"
elif (($patch_template_change == 'true' || $patch_document_change == 'true')); then
  patch_version_change="true"
fi

if $major_version_change == 'true' || $minor_version_change == 'true' || $patch_version_change == 'true'; then
  # Remove all generated files to ensure clean slate
  find . -not \( -name configs.json -or -name .gitignore -or -name LICENSE -or -name custom_package.json -or -name generate.sh -or -iwholename *.github* -or -iwholename *.git* -or -name . \) -exec rm -rf {} +

  if ! command -v ag &> /dev/null
  then
    npm install -g @asyncapi/generator
  fi
  # Generating code from the AsyncAPI document
  ag --force-write --output ./ ${url_to_asyncapi_document} https://github.com/${template_to_use}

  # Write new config file to ensure we keep the new state for next time
  contents="$(jq ".template_last_version = \"$template_current_version\" | .document_last_version = \"$document_current_version\"" configs.json)" && echo "${contents}" > configs.json
  # Write old version to package.json file as it was cleared by the generator
  contents="$(jq ".version = \"$library_last_version\"" package.json)" && echo "${contents}" > package.json
  # Merge custom package file with template generated
  jq -s '.[0] * .[1]' ./package.json ./custom_package.json > ./package_tmp.json
  rm ./package.json
  mv ./package_tmp.json ./package.json
  npm i
fi
mkdir -p ./.github/variables
echo "
major_version_change=$major_version_change
minor_version_change=$minor_version_change
patch_version_change=$patch_version_change
commit_message=$commit_message
" > ./.github/variables/generator.env
