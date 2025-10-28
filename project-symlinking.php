<?php

use function Laravel\Prompts\search;

require getenv('HOME').'/.composer/vendor/autoload.php';

$package = $argv[1] ?? null;

$codeDirectory = collect([
    getenv('HOME').'/Code',
    getenv('HOME').'/Herd',
    getenv('HOME').'/Valet',
])
    ->filter(fn (string $directory) => file_exists($directory))
    ->first();

$appComposerJson = json_decode(file_get_contents(getcwd().'/composer.json'), true);

$projects = collect(scandir('/Users/duncan/Code'))
    ->flatMap(fn (string $directory) => glob("/Users/duncan/Code/{$directory}" . '/*', GLOB_ONLYDIR))

    // Filter out non-PHP projects.
    ->reject(fn (string $directory) => ! file_exists("{$directory}/composer.json"))

    // Filter out any packages that aren't already installed.
    ->filter(function (string $directory) use ($appComposerJson) {
        $composerJson = json_decode(file_get_contents("{$directory}/composer.json"), true);

        return isset($composerJson['name']) 
            && in_array($composerJson['name'], array_keys([...$appComposerJson['require'] ?? [], ...$appComposerJson['require-dev'] ?? []]));
    })

    // Map stuff for the select prompt.
    ->mapWithKeys(function (string $directory) {
        $composerJson = json_decode(file_get_contents("{$directory}/composer.json"), true);

        return [$directory => $composerJson['name']];
    });

// When a package is provided as an argument, skip the search.
if ($package) {
    $project = $projects->flip()->get($package);
} else {
    $project = search(
        label: 'Which package do you want to link?',
        options: fn (string $value) => strlen($value) > 0
            ? $projects->filter(fn ($project) => str_contains($project, $value))->all()
            : $projects->all(),
    );
}

// Write to a temporary file so we can read it from the Bash script.
$composerJson = json_decode(file_get_contents("{$project}/composer.json"), true);

$vendorName = explode('/', $composerJson['name'])[0];
$packageName = explode('/', $composerJson['name'])[1];

// eg. /Users/duncan/Code/Statamic/cms|statamic|cms
file_put_contents('/tmp/tether.txt', "{$project}|{$vendorName}|{$packageName}");
