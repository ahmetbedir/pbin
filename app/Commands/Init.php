<?php

namespace App\Commands;

use App\Support\UserConfig;
use LaravelZero\Framework\Commands\Command;

use function Laravel\Prompts\text;

class Init extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'init
        {--privatebin-host= : The PrivateBin host URL (skips the prompt)}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Configure the PrivateBin host URL (stored in ~/.pbin/config.json).';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $config = new UserConfig;
        $current = $config->get('privatebin_host');

        $host = $this->option('privatebin-host') ?: text(
            label: 'PrivateBin Host URL',
            placeholder: 'https://privatebin.example.com',
            default: (string) ($current ?? ''),
            required: true,
            validate: fn (string $value) => $this->validateUrl($value),
            hint: 'Stored in ~/.pbin/config.json',
        );

        $host = rtrim(trim((string) $host), '/');

        if ($this->validateUrl($host) !== null) {
            $this->error('Invalid URL — it must start with http:// or https://');

            return self::FAILURE;
        }

        $config->set('privatebin_host', $host);

        $this->info("PrivateBin host saved: {$host}");
        $this->line("Config file: {$config->path()}");
        $this->line('You can now run: pbin create');

        return self::SUCCESS;
    }

    /**
     * Returns null when valid, or an error message string otherwise.
     */
    private function validateUrl(string $value): ?string
    {
        return preg_match('#^https?://\S+#i', trim($value))
            ? null
            : 'Enter a full URL starting with http:// or https://';
    }
}
