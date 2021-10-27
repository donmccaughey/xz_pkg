XZ Utils 5.2.5 for macOS
========================

This project builds a signed universal macOS installer package for [XZ
Utils][1], a general-purpose data compression tool and library.  It contains
the source distribution for XZ Utils 5.2.5.

[1]: http://tukaani.org/xz/ "XZ Utils"

## Building
The [`Makefile`][2] in the project root directory builds the installer package.
The following makefile variables can be set from the command line:

- `INSTALLER_SIGNING_ID`: The name of the 
    [Apple _Developer ID Installer_ certificate][3] used to sign the 
    installer.  The certificate must be installed on the build machine's
    Keychain.  Defaults to "Developer ID Installer: Donald McCaughey" if 
    not specified.
- `TMP`: The name of the directory for intermediate files.  Defaults to 
    "`./tmp`" if not specified.

[2]: https://github.com/donmccaughey/pkg-config_pkg/blob/master/Makefile
[3]: https://developer.apple.com/account/resources/certificates/list

To build and sign the executable and installer, run:

        $ make [INSTALLER_SIGNING_ID="<cert name>"] [TMP="<build dir>"]

Intermediate files are generated in the temp directory; the signed installer 
package is written into the project root with the name `pkg-config-0.29.2.pkg`.  

To remove all generated files (including the signed installer), run:

        $ make clean

## License

The installer and related scripts are copyright (c) 2021 Don McCaughey.
Different parts of XZ Utils are distributed under different licenses.  The
sources for the macOS installer package are distributed under GNU GPLv2.
See the LICENSE file for details.

