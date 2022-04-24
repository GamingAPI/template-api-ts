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

[ -d "./definitions" ] && rm -rf ./definitions

template_current_version=$(curl -sL https://api.github.com/repos/asyncapi/ts-nats-template/releases/latest | jq -r '.tag_name' | sed 's/v//')

git clone https://github.com/GamingAPI/definitions.git definitions
document_current_version=$(cat ./definitions/bundled/<<[ .cus.ASYNCAPI_FILE ]>> | jq -r '.info.version' | sed 's/v//')

semver_template_last_version=( ${template_last_version//./ } )
major_template_last_version=${semver_template_last_version[0]}
minor_template_last_version=${semver_template_last_version[1]}
patch_template_last_version=${semver_template_last_version[2]}
semver_template_current_version=( ${template_current_version//./ } )
major_template_current_version=${semver_template_current_version[0]}
minor_template_current_version=${semver_template_current_version[1]}
patch_template_current_version=${semver_template_current_version[2]}

if (($major_template_current_version > $major_template_last_version)); then
  major_version_change="true"
  commit_message="${commit_message}Template have changed to a new major version."
elif (($minor_template_current_version > $minor_template_last_version)); then
  minor_version_change="true"
  commit_message="${commit_message}Template have changed to a new minor version."
elif (($patch_template_current_version > $patch_template_last_version)) && (($minor_template_current_version < $minor_template_last_version)) && (($major_template_current_version < $major_template_last_version)); then
  patch_version_change="true"
  commit_message="${commit_message}Template have changed to a new patch version."
fi

semver_document_last_version=( ${document_last_version//./ } )
major_document_last_version=${semver_document_last_version[0]}
minor_document_last_version=${semver_document_last_version[1]}
patch_document_last_version=${semver_document_last_version[2]}
semver_document_current_version=( ${document_current_version//./ } )
major_document_current_version=${semver_document_current_version[0]}
minor_document_current_version=${semver_document_current_version[1]}
patch_document_current_version=${semver_document_current_version[2]}

if (($major_document_current_version > $major_document_last_version)); then
  major_version_change="true"
  commit_message="${commit_message}AsyncAPI document have changed to a new major version."
elif (($minor_document_current_version > $minor_document_last_version)); then
  minor_version_change="true"
  commit_message="${commit_message}AsyncAPI document have changed to a new minor version."
elif (($patch_document_current_version > $patch_document_last_version && $minor_document_current_version < $minor_document_last_version && $major_document_current_version < $major_document_last_version)); then
  patch_version_change="true"
  commit_message="${commit_message}AsyncAPI document have changed to a new patch version."
fi

if $major_version_change == 'true' || $minor_version_change == 'true' || $patch_version_change == 'true'; then
  # Remove previous files to ensure clean slate
  find . -not \( -name configs.json -or -name .gitignore -or -name LICENSE -or -name custom_package.json -or -name generate.sh -or -iwholename *.github* -or -iwholename *./definitions* -or -iwholename *.git* -or -name . \) -exec rm -rf {} +

  # Generating client from the AsyncAPI document
  if ! command -v ag &> /dev/null
  then
    npm install -g @asyncapi/generator
  fi

  ag --force-write --output ./ ./definitions/bundled/<<[ .cus.ASYNCAPI_FILE ]>> @asyncapi/ts-nats-template

  # Write new config file to ensure we keep the new state for next time
  contents="$(jq ".template_last_version = \"$template_current_version\" | .document_last_version = \"$document_current_version\"" configs.json)" && echo "${contents}" > configs.json
  # Write old version to package.json file as it was cleared by the generator
  contents="$(jq ".version = \"$library_last_version\"" package.json)" && echo "${contents}" > package.json
  # Merge custom package file with template generated
  jq -s '.[0] * .[1]' ./package.json ./custom_package.json > ./package_tmp.json
  rm ./package.json
  mv ./package_tmp.json ./package.json
  rm -rf ./definitions
  npm i
fi
mkdir -p ./.github/variables
echo "
major_version_change="$major_version_change"
minor_version_change="$minor_version_change"
patch_version_change="$patch_version_change"
" > ./.github/variables/generator.env
rm -rf ./definitions
