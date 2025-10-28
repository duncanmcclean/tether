# Tether

Link local composer packages to your sandbox for local development.

> > [!NOTE]
> Still in active development. Things may change without notice.

## Rationale

It's easy to setup a composer repository for local package development. 

However, it's not long until you face dependency conflicts, or issues trying to ensure CSS/JS assets are symlinked correctly.

This package (if you can even call it that) discovers which packages you have cloned down, and lets you easily symlink them into your sandbox application.

## Installation

TODO

<!-- 1. MacOS
2. PHP & Composer
3. Download `tether.sh` and copy it to `/usr/local/bin`. Remove the `.sh` file extension.
4. Ensure it has the right permissions:
    ```bash
    sudo chmod +x /usr/local/bin/tether
    ```
5. Add `/usr/local/bin` to your `PATH` if you haven't already:
    ```bash
    export PATH=/usr/local/bin:$PATH
    ```
6. Run `tether` -->

## Usage

TODO

## Roadmap

* [ ] Proper install & usage docs
* [ ] Re-write purely in Bash
* [ ] Ability to `untether` packages (eg. unlink them and use the _normal_ version)

## Contributing

1. Fork the repository
2. Clone down locally
3. Ensure `tether.sh` has the right permissions:
    ```bash
    sudo chmod +x /path/to/your/clone/tether.sh
    ```
4. Symlink to `/usr/local/bin`:
    ```bash
    sudo ln -s /path/to/your/clone/tether.sh /usr/local/bin/tether
    ```