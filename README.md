Based on https://rclayton.silvrback.com/templatizing-github-template-repos

This template needs to be imploded to be usable. Create the config file `customize.json` in the same dir as `customize`, and then run the script.

Placeholder syntax is `<<[ .cus.foo ]>>`

These are the supported placeholders:
```
ASYNCAPI_FILE='rust.asyncapi.json'
REPOSITORY_DESCRIPTION=''
REPOSITORY_NAME=''
```

## Required secrets for workflow

- NPM_TOKEN
- GH_TOKEN