# esp32e22-fw

## Overview

`esp32e22-fw` is a firmware repository for the `esp32e22` platform. It is used to store and distribute prebuilt firmware binaries required by the solution, including both `Wi-Fi` and `Bluetooth` functionality.

This repository serves as a unified firmware delivery source for both the `esp32e22` `Linux` driver and `Windows` driver. Its primary purpose is binary distribution and version management rather than firmware source development.

## Repository Purpose

- Provide a centralized location for `esp32e22` firmware binaries
- Support driver integration on both `Linux` and `Windows`
- Keep `Wi-Fi` and `Bluetooth` firmware artifacts aligned under one repository
- Simplify release management and firmware version tracking

## Notes

- This repository primarily contains released firmware artifacts in binary form
- Driver projects can reference this repository as the firmware source during packaging or integration
- If additional release metadata is needed, it is recommended to maintain version, changelog, and compatibility information together with the binaries
- See [`COPYRIGHT.md`](COPYRIGHT.md) for copyright and third-party attribution information

## Firmware File and Versioning

Each official release in this repository contains exactly one firmware binary
at a fixed path:

- `esp32e22-fw.bin` — the firmware binary (filename never changes)
- `manifest.json` — release metadata (version, source commit, build date, etc.)

Firmware versions are monotonically increasing integers. `version: 0` is
reserved as a non-official placeholder; official releases start at `1` and are
exposed as git tags (`v1`, `v2`, `v3`, ...). The Secure Download variant uses
the same binary format and the same filename; whether the current firmware
supports Secure Download is recorded in `manifest.json`.

During the non-official `version: 0` placeholder stage, the repository may
temporarily contain only metadata files and no firmware binary yet.

For the full versioning, manifest schema, and release workflow, see
[VERSIONING.md](VERSIONING.md).

### Release Example

After replacing `esp32e22-fw.bin` with a newly built firmware image, update
`manifest.json` with:

```bash
tools/update-manifest.sh \
    --version 1 \
    --source-commit a3f9c129 \
    --source-branch main \
    --secure-download false
```

## Related Repository

For Linux driver integration, see the sibling driver repository
[`esp32e22-linux-driver`](../esp32e22-linux-driver).

Windows driver integration may be documented in a separate repository when
available.

To keep these references portable across GitLab and GitHub mirrors, links are
expressed as relative repository paths rather than host-specific URLs.

## Integration

This repository may be consumed by upstream projects as a Git submodule for
firmware binary delivery, release management, and version tracking.

Upstream projects may place this repository under a directory such as
`firmware/`. When mirrored across multiple Git hosting services, relative
submodule URLs such as `../esp32e22-fw` may be used where appropriate to keep
submodule resolution consistent across mirrors.

## License

This repository is licensed under the Apache License, Version 2.0. See the
[LICENSE](LICENSE) file for the full license text and [COPYRIGHT.md](COPYRIGHT.md)
for copyright and third-party attribution information.

The firmware in this repository is distributed in binary (Object) form only;
source code is not included.
