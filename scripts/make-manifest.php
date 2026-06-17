<?php

declare(strict_types=1);

$dist = $argv[1] ?? __DIR__.'/../dist';
$dist = realpath($dist);

if ($dist === false) {
    fwrite(STDERR, "Distribution directory does not exist.\n");
    exit(1);
}

$assets = [];
$checksums = [];

foreach (glob($dist.'/privacy-filter-*.{tar.gz,zip}', GLOB_BRACE) ?: [] as $path) {
    $filename = basename($path);

    if (! preg_match('/^privacy-filter-(?<os>linux|darwin|windows)-(?<arch>x64|arm64)\.(?<extension>tar\.gz|zip)$/', $filename, $matches)) {
        continue;
    }

    $sha256 = hash_file('sha256', $path);

    $assets[] = [
        'os' => $matches['os'],
        'arch' => $matches['arch'],
        'cpuOnly' => true,
        'filename' => $filename,
        'sha256' => $sha256,
    ];

    $checksums[] = "{$sha256}  {$filename}";
}

usort($assets, fn (array $a, array $b): int => [$a['os'], $a['arch']] <=> [$b['os'], $b['arch']]);
sort($checksums);

$manifest = [
    'schemaVersion' => 1,
    'assets' => $assets,
];

file_put_contents($dist.'/manifest.json', json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL);
file_put_contents($dist.'/checksums.txt', implode(PHP_EOL, $checksums).PHP_EOL);
