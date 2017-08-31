RPM specification file, and packaging scripts for the Google Test library.

The purpose of this project is to build gtest RPMs with the alternative
devtoolset tool chains (e.g., devtoolset-2-toolchain) on RHEL 6.  If you are
using one of these tool chains (e.g, because you need a more recent compiler on
RHEL 6) and want to use gtest with them, you'll need to build gtest with the
tool chain you are using and install it in the appropriate location for the
used tool chain.

To build an RPM, such as gtest-devtoolset2-1.8.0:

```BASH
./bin/build.sh
```

You can run `./bin/build.sh --help` to see the options you can specify.

The built RPMs will end up under `build/RPMS`.

You'll need to have Docker installed, if you're not running on RHEL 6.

You'll need a username and password for a registered user Red Hat user with a
RHEL 6 subscription (to be able to access Yum packages).

The RPMs will be built for the processor your machine is running.
Cross-compilation has not been implemented.
