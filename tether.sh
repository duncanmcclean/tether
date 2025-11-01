#!/bin/bash

set -e

# ------------------------------------------------------------------------------
# Ensure dependencies are installed
# ------------------------------------------------------------------------------

# TODO: jv check

if ! command -v gum &> /dev/null; then
    gum style --foreground 196 --border-foreground 196 --border double \
        --align center --width 60 --margin "1 1" \
        '❌ gum is required to use Tether' \
        'Install it via "brew install gum"'

    exit 1
fi


# ------------------------------------------------------------------------------
# Package Selection
# ------------------------------------------------------------------------------

PACKAGE="$1"

CODE_DIRECTORY=""
for dir in "$HOME/Code" "$HOME/Herd" "$HOME/Valet"; do
    if [[ -d "$dir" ]]; then
        CODE_DIRECTORY="$dir"
        break
    fi
done

if [[ -z "$CODE_DIRECTORY" ]]; then
    gum style \
        --foreground 196 --border-foreground 196 --border double \
        --align center --width 60 --margin "1 1" \
        '❌ Could not locate your code directory. '

    exit 1
fi

if [[ ! -f "$(pwd)/composer.json" ]]; then
    gum style \
        --foreground 196 --border-foreground 196 --border double \
        --align center --width 60 --margin "1 1" \
        '❌ No composer.json file the current directory.'

    exit 1
fi

CURRENT_COMPOSER_JSON="$(pwd)/composer.json"
DEPENDENCIES=$(jq -r '(.require // {}) + (.["require-dev"] // {}) | keys[]' "$CURRENT_COMPOSER_JSON" 2>/dev/null || echo "")

if [[ -z "$DEPENDENCIES" ]]; then
    gum style \
        --foreground 196 --border-foreground 196 --border double \
        --align center --width 60 --margin "1 1" \
        '❌ Unable to parse dependencies from composer.json'

    exit 1
fi

TEMP_PROJECTS=$(mktemp)
TEMP_OPTIONS=$(mktemp)

trap 'rm -f "$TEMP_PROJECTS" "$TEMP_OPTIONS"' EXIT

# Discover packages in the user's code directory.
for depth in 1 2 3; do
    find "$CODE_DIRECTORY" -maxdepth $depth -name "composer.json" -type f | while read -r composer_file; do
        project_dir=$(dirname "$composer_file")
        
        # Skip if composer.json doesn't exist or is not readable
        if [[ ! -r "$composer_file" ]]; then
            continue
        fi
        
        # Extract package name from composer.json
        package_name=$(jq -r '.name // empty' "$composer_file" 2>/dev/null)
        
        # Skip if no package name
        if [[ -z "$package_name" || "$package_name" == "null" ]]; then
            continue
        fi
        
        # Check if this package is in our dependencies
        if echo "$DEPENDENCIES" | grep -q "^$package_name$"; then
            vendor_name=$(echo "$package_name" | cut -d'/' -f1)
            package_only=$(echo "$package_name" | cut -d'/' -f2)
            echo "$project_dir|$vendor_name|$package_only|$package_name" >> "$TEMP_PROJECTS"
        fi
    done
done

if [[ ! -s "$TEMP_PROJECTS" ]]; then
    gum style \
        --foreground 196 --border-foreground 196 --border double \
        --align center --width 60 --margin "1 1" \
        '❌ No linkable packages found in $CODE_DIRECTORY' \
        'Make sure your packages are in subdirectories and have composer.json files'

    exit 1
fi

# When package is passed as an argument, find it.
# Otherwise, let the user select a package.
if [[ -n "$PACKAGE" ]]; then
    PROJECT_LINE=$(grep "|$PACKAGE$" "$TEMP_PROJECTS" || true)

    if [[ -z "$PROJECT_LINE" ]]; then
        gum style \
            --foreground 196 --border-foreground 196 --border double \
            --align center --width 60 --margin "1 1" \
            '❌ Could not locate package in your code directory.'

        exit 1
    fi
else
    while IFS='|' read -r project_dir vendor_name package_only package_name; do
        echo "$package_name" >> "$TEMP_OPTIONS"
    done < "$TEMP_PROJECTS"
    
    SELECTED_PACKAGE=$(gum filter --placeholder "Which package do you want to link?" < "$TEMP_OPTIONS")
    
    if [[ -z "$SELECTED_PACKAGE" ]]; then
        gum style --foreground 208 --border-foreground 208 --border double \ 
            --align center --width 60 --margin "1 1" \
            "⚠️  No package selected"

        exit 1
    fi
    
    PROJECT_LINE=$(grep "|$SELECTED_PACKAGE$" "$TEMP_PROJECTS")
fi

PACKAGE_PATH=$(echo "$PROJECT_LINE" | cut -d'|' -f1)
PACKAGE_VENDOR=$(echo "$PROJECT_LINE" | cut -d'|' -f2)
PACKAGE_NAME=$(echo "$PROJECT_LINE" | cut -d'|' -f3)

gum style --foreground 33 "📦 Selected: $PACKAGE_VENDOR/$PACKAGE_NAME"
gum style --foreground 240 "📁 Project directory: $PACKAGE_PATH"


# ------------------------------------------------------------------------------
# Set up repository & update constraint
# ------------------------------------------------------------------------------

if [[ " $* " == *" --force "* ]]; then
    rm -rf vendor/$PACKAGE_VENDOR/$PACKAGE_NAME
    ln -s $PACKAGE_PATH vendor/$PACKAGE_VENDOR/$PACKAGE_NAME

    gum style \
        --foreground 29 --border-foreground 29 --border double \
        --align center --width 60 --margin "1 1" \
        '✅ Forcefully symlinked package' \
        'To untether, run `composer reinstall ...`'
else
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
        --foreground 29 --border-foreground 29 --border double \
        --align center --width 60 --margin "1 1" \
        '✅ Updated composer constraint'
fi


# ------------------------------------------------------------------------------
# Symlink assets
# ------------------------------------------------------------------------------

duncanmcclean_statamic_cargo() {
    if [ -d "public" ]; then
        rm -rf public/vendor/statamic-cargo
        ln -s $PACKAGE_PATH/resources/dist public/vendor/statamic-cargo
    fi

    if [ -d "resources/views/checkout" ]; then
        rm -rf resources/views/checkout
        ln -s $PACKAGE_PATH/resources/views/checkout resources/views/checkout

        rm -rf public/checkout-build
        ln -s $PACKAGE_PATH/resources/dist-checkout public/checkout-build
    fi
}

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
        --foreground 29 --border-foreground 29 --border double \
        --align center --width 60 --margin "1 1" \
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
        --foreground 29 --border-foreground 29 --border double \
        --align center --width 60 --margin "1 1" \
        '✅ Symlinked assets'
fi