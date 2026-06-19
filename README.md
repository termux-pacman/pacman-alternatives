# pacman-alternatives
A utility for managing symbolic links (alternatives) of pacman packages.

## Installation
```bash
git clone https://github.com/termux-pacman/pacman-alternatives.git
cd pacman-alternatives

# on pacman-based Termux
make

# on pacman-based Linux distributions
sudo make
```
Variables for installation configuration:
Variable | Type | Description | Default
---|---|---|---
`DEF_OS` | `android`/`linux` | host operating system | automatically detects host OS
`PREFIX` | fullpath | main path for installing and routing system files | on Linux - `/usr`, on Android (Termux) - `/data/data/com.termux/files/usr`
`DESTDIR` | empty/path | path to installing temporary directory | empty
`SYSDIR` | fullpath | main path for routing alternative (links and root files) paths | on Linux - `/`, on Android (Termux) - `/data/data/com.termux/files/usr/`
`LINKDIR` | empty/fullpath | path for routing links of alternatives | empty
`ROOTDIR` | empty/fullpath | path for routing root files of alternatives | empty
`ALTER_FILES_PATH` | path/fullpath | path to directory for alternative files | `share/pacman-alternatives`
`ENABLED_ALTERS_PATH` | path/fullpath | path to directory for active alternatives | `var/lib/pacman/alternatives`
`READER_USER` | username/empty | user for reading alternative files | on Linux - `pacman-alternatives`, on Android (Termux) - empty (disabling use of reader user)
`BINDIR` | fullpath | path to `bin/` | `$(PREFIX)/bin`
`BASHPATH` | fullpath | path to bash | `$(BINDIR)/bash`
`ALPMDIR` | fullpath | path to ALPM directory | `$(PREFIX)/share/libalpm`
`ALPM_HOOK_DIR` | fullpath | path to hooks directory of ALPM | `$(ALPMDIR)/hooks`
`ALPM_SCRIPT_DIR` | fullpath | path to scripts directory of ALPM | `$(ALPMDIR)/scripts`

## Operations
Name | Flag | Description
---|---|---
Disable | `-D`/`--disable` | Disable enabled alternative(s)
Enable | `-E`/`--enable` | Enable available (disabled) alternative(s)
Install | `-I`/`--install` | Install alternative file(s) into system
Query | `-Q`/`--query` | Output of information about alternative(s), checking alternative(s)
Reject | `-R`/`--reject` | Reject selected alternative(s)
Select | `-S`/`--select` | Select enabled alternative(s)
Uninstall | `-U`/`--uninstall` | Uninstall alternative file(s) from system

## Example of use
Installing `nano` (`editor:nano`) alternative file:
```bash
pacman-alternatives -I ./nano.alt
```

Enabling `editor:nano` alternative and selecting it in auto mode:
```bash
pacman-alternatives -Ea nano
```

Summary of enabled alternatives by `editor` alternative group:
```bash
pacman-alternatives -Q editor:
```

Selecting alternative by `editor` alternative group in manual mode:
```bash
pacman-alternatives -S editor:
```

Rejecting selected alternative in `editor` alternative group and replacing it:
```bash
pacman-alternatives -Rr editor:
```

Disabling and rejecting `editor:nano` alternative without confirmation:
```bash
pacman-alternatives -Dr :nano --noconfirm
```

Uninstalling `nano` (`editor:nano`) alternative from system without confirmation:
```bash
pacman-alternatives -U nano --noconfirm
```

Checking all enabled alternatives:
```bash
pacman-alternatives -Qc
```

## System variables
Variable | Type | Description
--- | --- | ---
`PA_RUN_IN_ALPM_HOOKS` | bool | configure output and processing for the ALPM environment
`PA_VERBOSE` | bool | enable verbose mode
`PA_SYSDIR` | fullpath | set path for routing alternative (links and root files) paths (must begin and end with `/`)
`PA_ROOTDIR` | empty/fullpath | set path for routing root files of alternatives (must begin and end with `/`)
`PA_LINKDIR` | empty/fullpath | set path for routing links of alternatives (must begin and end with `/`)
`PA_PREFIX` | fullpath | set path for routing system files
`PA_ALTER_FILES_PATH` | path/fullpath | set path to directory for alternative files (if relative path is specified, full path is formed using `_pa_prefix`: `"${_pa_prefix}/${PA_ALTER_FILES_PATH}"`)
`PA_ENABLED_ALTERS_PATH` | path/fullpath | set path to directory for active alternatives (if relative path is specified, full path is formed using `_pa_prefix`: `"${_pa_prefix}/${PA_ENABLED_ALTERS_PATH}"`)
`PA_READER_USER` | username/empty | set reader username (if empty, the use of reader user is disabled)

## Syntax file alternative
File alternative is a shell script in the `.alt` format, which stores `alter_group_*` functions that allow to flexibly configure alternatives and easily collect alternative metadata from them (`group:name:priority:link:root`).  

Syntax rules:
- Alternative name and alternative group name can consist of alphabets, numbers and the special characters `-`/`_`.
- Path in the `sysdir`, `linkdir` and `rootdir` variables must begin and end with the `/` character.
- Value of `priority` variable must be integer.
- Paths specified in the `associations` variable must be relative.

```bash
# example file alternative `example.alt`

priority=10
sysdir="/usr/local/"

alter_group_group1() {
    associations=(
        bin/link1_1:bin/root1_1
        bin/link1_2:bin/root1_2
    )
    # final metadata:
    # - group1:example:10:/usr/local/bin/link1_1:/usr/local/bin/root1_1
    # - group1:example:10:/usr/local/bin/link1_2:/usr/local/bin/root1_2
}

alter_group_group2() {
    sysdir+="bin/"
    associations=(link2:root2)
    # final metadata:
    # - group2:example:10:/usr/local/bin/link2:/usr/local/bin/root2
}

function alter_group_group3 {
    priority=20
    linkdir="/usr/"
    rootdir="/usr/local/"
    associations=(bin/link3:sbin/root3)
    # final metadata:
    # - group3:example:20:/usr/bin/link3:/usr/local/sbin/root3
}
```
