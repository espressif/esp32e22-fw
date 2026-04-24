# Firmware Versioning

This document describes the firmware versioning, file naming, and release
metadata conventions used by this repository.

## File Layout

Each official firmware release in this repository contains exactly one firmware
binary, with a fixed filename:

```text
esp32e22-fw/
├── esp32e22-fw.bin       # the only firmware binary; filename never changes
├── manifest.json         # release metadata (version, source commit, etc.)
└── ...
```

Drivers and tooling can hard-code the path to `esp32e22-fw.bin` without
embedding any version information in the path. During the non-official
`version: 0` placeholder stage, the repository may temporarily contain only the
release metadata files and no firmware binary yet.

## Version Numbering

The firmware uses a single monotonically increasing integer as its version
number:

```text
0, 1, 2, 3, ...
```

Rules:

- `version: 0` is reserved as a **non-official** placeholder value. It
  indicates that the firmware in the repository is a draft, work-in-progress,
  or initial template and is not an official release. No git tag is created
  for `version: 0`.
- The first official release uses `version: 1`.
- Each subsequent official release **must** increase `version` by exactly `1`
  from the previous official release.
- The version number **never** decreases and is **never** reused.
- There are no `MAJOR.MINOR.PATCH` parts; firmware compatibility is tracked
  through release notes and changelog entries, not through the version number
  itself.

Each official release is also tagged in this repository:

```text
v1, v2, v3, ...
```

The tag and the `version` field in `manifest.json` must always match for
official releases.

## Secure Download

The Secure Download variant of the firmware uses **the same binary format and
the same filename** as the regular firmware. There is no separate
`.sec`-suffixed file.

Whether the current firmware is built with Secure Download support is recorded
in `manifest.json` via the `secure_download` boolean field. Drivers read this
field to decide which loading path to use.

## Manifest

Each release ships with a `manifest.json` describing the firmware. It is the
single source of truth for version, build, and source-traceability information.

### Schema

```json
{
  "chip": "esp32e22",
  "firmware": {
    "version": 1,
    "build_date": "2026-04-20T12:34:56+08:00",
    "size_bytes": 1234567,
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  },
  "source": {
    "repo": "esp-firmware-system",
    "commit": "a3f9c129",
    "branch": "main"
  },
  "features": ["wifi", "bt"],
  "secure_download": false
}
```

### Field Reference

| Field | Type | Description |
|---|---|---|
| `chip` | string | Target chip identifier. Always `esp32e22` for this repository. |
| `firmware.version` | integer | Monotonically increasing firmware version. `0` is reserved as a non-official placeholder; official releases start at `1`. |
| `firmware.build_date` | string | Firmware build timestamp: local wall time with UTC offset (RFC 3339), e.g. `2026-04-20T12:34:56+08:00`. |
| `firmware.size_bytes` | integer | Size of `esp32e22-fw.bin` in bytes. |
| `firmware.sha256` | string | SHA-256 of `esp32e22-fw.bin`, lowercase hex. |
| `source.repo` | string | Name of the firmware source repository. Always `esp-firmware-system`. |
| `source.commit` | string | 8-character short commit SHA in `esp-firmware-system` from which this firmware was built. |
| `source.branch` | string | Branch name in `esp-firmware-system` at build time. Required for official releases. |
| `features` | array of strings | Functional features supported by the firmware, e.g. `wifi`, `bt`. |
| `secure_download` | boolean | Whether this firmware supports Secure Download. |

### Driver Behaviour

Drivers consume the firmware as follows:

1. Load the firmware binary from the fixed path `esp32e22-fw.bin`.
2. Read `manifest.json` to obtain the version, source commit, and feature
   information.
3. Optionally verify the firmware integrity using `firmware.sha256`.
4. Use `secure_download` to decide whether to load the firmware via the secure
   download path or the regular path.
5. Log a single line such as
   `esp32e22-fw v3 (src esp-firmware-system @ a3f9c129, secure_download=false)`
   to aid in field debugging.

Drivers should tolerate a missing or partially populated `manifest.json` by
falling back to safe defaults and emitting a warning.

## Release Workflow

For each new firmware release:

1. Build the firmware in `esp-firmware-system` and capture:
   - the source commit SHA,
   - the source branch name,
   - the build timestamp.
2. In this repository:
   1. Replace `esp32e22-fw.bin` with the new binary.
   2. Update `manifest.json`:
      - set `firmware.version` to `1` for the first official release, or increment it by exactly `1` for each subsequent official release,
      - update `firmware.build_date`, `firmware.size_bytes`, `firmware.sha256`,
      - update `source.commit` and `source.branch`,
      - update `features` and `secure_download` if applicable.
   3. Update `CHANGELOG.md` (if present) with the new version.
3. Commit the changes and create an annotated git tag `v<version>`
   (for example, `v3`).
4. Push the commit and the tag.

It is recommended to automate the manifest update and tagging in CI so that
the manifest content always matches the binary.

## Tooling

- [`tools/update-manifest.sh`](tools/update-manifest.sh) — helper script that
  computes `firmware.size_bytes` and `firmware.sha256` from
  `esp32e22-fw.bin` and rewrites `manifest.json` with the values supplied via
  command-line options. It also enforces the version transition rules described
  above and requires `--source-branch` so the manifest never carries a stale
  branch value from a previous release.
- [`manifest.schema.json`](manifest.schema.json) — JSON Schema describing the
  structure and constraints of `manifest.json`. It can be used in CI to
  validate the manifest before release, for example:

  ```bash
  python3 -m pip install jsonschema
  python3 -c "import json, jsonschema; \
      jsonschema.validate( \
          json.load(open('manifest.json')), \
          json.load(open('manifest.schema.json')))"
  ```

- [`CHANGELOG.md`](CHANGELOG.md) — human-readable release history. Add a new
  entry for each release, following the template in that file.
