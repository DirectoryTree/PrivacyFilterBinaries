<div align="center">
<h1>Privacy Filter Binaries</h1>
<p>
<a href="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/build-binaries.yml"><img src="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/build-binaries.yml/badge.svg?branch=master" alt="Build binaries status"></a>
<a href="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/integration-test-binaries.yml"><img src="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/integration-test-binaries.yml/badge.svg?branch=master" alt="Integration test binaries status"></a>
</p>
<p>Prebuilt <code>privacy-filter.cpp</code> binaries for Linux, macOS, and Windows.</p>
</div>

## Installation

Download the archive for your platform from the latest release:

```bash
curl -L -o privacy-filter.tar.gz \
  https://github.com/DirectoryTree/PrivacyFilterBinaries/releases/latest/download/privacy-filter-darwin-arm64.tar.gz

tar -xzf privacy-filter.tar.gz
```

Available release assets:

```text
privacy-filter-linux-x64.tar.gz
privacy-filter-darwin-x64.tar.gz
privacy-filter-darwin-arm64.tar.gz
privacy-filter-windows-x64.zip
manifest.json
checksums.txt
```

The executable is located at:

```text
privacy-filter-*/bin/privacy-filter
```

On Windows:

```text
privacy-filter-windows-x64/bin/privacy-filter.exe
```

## Setup

Download a compatible GGUF model:

```bash
mkdir -p models

curl -L -o models/privacy-filter-f16.gguf \
  https://huggingface.co/LocalAI-io/privacy-filter-GGUF/resolve/main/privacy-filter-f16.gguf
```

For automated installers, use the release manifest:

```text
https://github.com/DirectoryTree/PrivacyFilterBinaries/releases/latest/download/manifest.json
```

## Usage

Classify text from stdin:

```bash
echo 'Contact John Doe at jdoe@example.com from 555-0100.' \
  | ./privacy-filter-darwin-arm64/bin/privacy-filter --classify models/privacy-filter-f16.gguf 0.5
```

Example output:

```json
[
  {
    "entity_group": "email",
    "start": 20,
    "end": 36,
    "score": 0.9876,
    "text": "jdoe@example.com"
  }
]
```
