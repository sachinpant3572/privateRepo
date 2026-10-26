# Test signing key

`test.keystore` signs the sideload test APKs that CI builds, so each new build
installs over the previous one. Alias `test`, password `testbuild`.

The password is public. This key is for testing only: a Play Store release
needs its own private upload key, kept out of the repository.
