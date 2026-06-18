<div align="center">
<h1>Privacy Filter Binaries</h1>
<p>
<a href="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/build-binaries.yml"><img src="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/build-binaries.yml/badge.svg?branch=master" alt="Build binaries status"></a>
<a href="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/integration-test-binaries.yml"><img src="https://github.com/DirectoryTree/PrivacyFilterBinaries/actions/workflows/integration-test-binaries.yml/badge.svg?branch=master" alt="Integration test binaries status"></a>
</p>
<p>Prebuilt <a href="https://github.com/localai-org/privacy-filter.cpp"><code>privacy-filter.cpp</code></a> binaries for Linux, macOS, and Windows.</p>
</div>

## Installation

You may install the precompiled binaries and GGUF model using the following instructions.

> Both are required to use the `privacy-filter.cpp` command line tool. The binary is the executable that runs the classification, while the model contains the data and parameters needed for the classification process.

### Binary

Download the archive for your platform from the [latest release](https://github.com/DirectoryTree/PrivacyFilterBinaries/releases/latest):

```bash
curl -L -o privacy-filter.tar.gz \
  https://github.com/DirectoryTree/PrivacyFilterBinaries/releases/latest/download/privacy-filter-darwin-arm64.tar.gz

tar -xzf privacy-filter.tar.gz
```

### Model

Download the [GGUF model](https://huggingface.co/LocalAI-io/privacy-filter-GGUF):

```bash
mkdir -p models

curl -L -o models/privacy-filter-f16.gguf \
  https://huggingface.co/LocalAI-io/privacy-filter-GGUF/resolve/main/privacy-filter-f16.gguf
```

## Usage

Classify text from stdin:

```bash
echo 'Contact John Doe at jdoe@example.com from 555-0100.' \
  | ./privacy-filter-darwin-arm64/bin/privacy-filter --classify models/privacy-filter-f16.gguf 0.5
```

The final argument is the classification threshold. It is the minimum confidence score an entity must meet before it is returned. Increasing the threshold returns fewer, higher-confidence entities, while decreasing it may return more entities with lower confidence.
