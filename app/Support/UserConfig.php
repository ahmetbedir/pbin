<?php

namespace App\Support;

/**
 * Per-user configuration stored at ~/.pbin/config.json.
 *
 * Keeps machine-local settings (notably the private PrivateBin host) off the
 * source tree and out of the distributed binary — each user sets their own.
 */
class UserConfig
{
    public function path(): string
    {
        $home = getenv('HOME') ?: getenv('USERPROFILE') ?: sys_get_temp_dir();

        return rtrim($home, '/\\').'/.pbin/config.json';
    }

    /**
     * @return array<string, mixed>
     */
    public function all(): array
    {
        $path = $this->path();
        if (! is_file($path)) {
            return [];
        }

        $data = json_decode((string) file_get_contents($path), true);

        return is_array($data) ? $data : [];
    }

    public function get(string $key, mixed $default = null): mixed
    {
        return $this->all()[$key] ?? $default;
    }

    public function set(string $key, mixed $value): void
    {
        $data = $this->all();
        $data[$key] = $value;

        $dir = dirname($this->path());
        if (! is_dir($dir)) {
            mkdir($dir, 0700, true);
        }

        file_put_contents(
            $this->path(),
            json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE).PHP_EOL,
        );
        @chmod($this->path(), 0600);
    }
}
