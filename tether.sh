#!/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

php $SCRIPT_DIR/project-symlinking.php $1

if [ ! -e "/tmp/tether.txt" ]; then
    exit 1
fi

read contents < /tmp/tether.txt
IFS='|' read -r PACKAGE_PATH PACKAGE_VENDOR PACKAGE_NAME <<< "$contents"
rm /tmp/tether.txt

# ------------------------------------------------------------------------------
# Set up repository & update constraint
# ------------------------------------------------------------------------------

composer config repositories.$PACKAGE_NAME path $PACKAGE_PATH

tag=$(cd $PACKAGE_PATH && git describe --tags --abbrev=0)
tag=${tag#v}
branch=$(cd $PACKAGE_PATH && git rev-parse --abbrev-ref HEAD)

if [[ $branch =~ ^[0-9]+\.[0-9]+$ ]]; then
    constraint="$branch.x-dev"
elif [[ $branch =~ ^[0-9]+\.x+$ ]]; then
    constraint="$branch-dev"
else
    constraint="dev-$branch"
fi

composer require "$PACKAGE_VENDOR/$PACKAGE_NAME $constraint as $tag" -w --no-interaction "$@" || exit 1

gum style \
    --foreground 46 --border-foreground 46 --border double \
    --align center --width 50 --margin "1 1" \
    '✅ Updated composer constraint'


# ------------------------------------------------------------------------------
# Symlink assets
# ------------------------------------------------------------------------------

statamic_cms() {    
    if [ -d "public" ]; then
        rm -rf public/vendor/statamic
        mkdir -p public/vendor/statamic
    fi

    ln -s "$PACKAGE_PATH/resources/dist" public/vendor/statamic/cp
    ln -s "$PACKAGE_PATH/resources/dist-dev" public/vendor/statamic/cp-dev
    ln -s "$PACKAGE_PATH/resources/dist-frontend" public/vendor/statamic/frontend

    rm -rf "$PACKAGE_PATH/resources/dist-package"
    ln -s "$PACKAGE_PATH/packages/cms" "$PACKAGE_PATH/resources/dist-package"

    rm -f "$PACKAGE_PATH/packages/cms/src/ui.css"
    ln -s "$PACKAGE_PATH/packages/ui/src/ui.css" "$PACKAGE_PATH/packages/cms/src/ui.css"
}

HANDLER_NAME="${PACKAGE_VENDOR}_${PACKAGE_NAME}"
HANDLER_NAME="${HANDLER_NAME//-/_}"

if declare -f "$HANDLER_NAME" > /dev/null; then
    $HANDLER_NAME

    gum style \
        --foreground 46 --border-foreground 46 --border double \
        --align center --width 50 --margin "1 1" \
        '✅ Symlinked assets'
elif [[ -d "public" ]]; then
    if [ -d "$PACKAGE_PATH/dist/build" ]; then
        rm -rf public/vendor/$PACKAGE_NAME
        ln -s $PACKAGE_PATH/dist public/vendor/$PACKAGE_NAME
    elif [ -d "$PACKAGE_PATH/resources/dist/build" ]; then
        rm -rf public/vendor/$PACKAGE_NAME
        ln -s $PACKAGE_PATH/resources/dist public/vendor/$PACKAGE_NAME
    fi

    gum style \
        --foreground 46 --border-foreground 46 --border double \
        --align center --width 50 --margin "1 1" \
        '✅ Symlinked assets'
fi