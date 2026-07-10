<?php

namespace App\Commands;

use App\Prompts\SubmittableTextareaPrompt;
use App\Services\PrivateBin;
use App\Support\UserConfig;
use Laravel\Prompts\Elements\Element;
use LaravelZero\Framework\Commands\Command;

use function Laravel\Prompts\callout;
use function Laravel\Prompts\clear;
use function Laravel\Prompts\password;
use function Laravel\Prompts\select;
use function Laravel\Prompts\spin;

class CreateBin extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'create';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Create a new bin in the PrivateBin instance.';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $host = (new UserConfig)->get('privatebin_host') ?: config('privatebin.url');
        if (! $host) {
            $this->error('PrivateBin host is not configured. Run `pbin init` first.');

            return self::FAILURE;
        }
        $host = rtrim((string) $host, '/');

        clear();

        $content = (new SubmittableTextareaPrompt(
            label: 'Content',
            placeholder: 'Enter the content you want to share',
            required: true,
            hint: 'This is encrypted in your terminal — the server never sees it.',
        ))->prompt();

        $format = select(
            label: 'Format',
            options: [
                'plaintext' => 'Plain Text',
                'markdown' => 'Markdown',
                'syntaxhighlighting' => 'Source Code',
            ],
            default: 'plaintext',
        );

        $expiry = select(
            label: 'Expiry',
            options: [
                '5min' => '5 minutes',
                '1hour' => '1 hour',
                '1day' => '1 day',
                '1week' => '1 week',
                'never' => 'Never',
            ],
            default: '1day',
        );

        $password = password(
            label: 'Password (optional)',
            hint: 'If left empty, the bin will be created without a password',
        );

        $type = select(
            label: 'Type',
            options: [
                'burn' => 'Delete after reading?',
                'discussion' => 'Open discussion (comments)',
                'none' => 'None',
            ],
            default: 'burn',
        );

        $burnAfterReading = $type === 'burn';
        $openDiscussion = $type === 'discussion';

        $client = new PrivateBin($host);

        try {
            $result = spin(
                message: 'Encrypting and creating bin...',
                callback: fn () => $client->create(
                    content: $content,
                    expiry: $expiry,
                    password: $password !== '' ? $password : null,
                    burnAfterReading: $burnAfterReading,
                    format: $format,
                    openDiscussion: $openDiscussion,
                ),
            );
        } catch (\Throwable $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $copied = $this->copyToClipboard($result['view_url']);

        callout('PrivateBin Created', [
            'Your bin has been successfully created.',
            'You can view it using the link provided below.',
            Element::link($result['view_url']),
        ], info: $copied ? 'View URL copied' : '');

        return self::SUCCESS;
    }

    /**
     * Copy the given text to the system clipboard, returning whether it worked.
     *
     * Tries the platform-appropriate clipboard utilities in order and stops at
     * the first one that succeeds.
     */
    private function copyToClipboard(string $text): bool
    {
        $candidates = match (PHP_OS_FAMILY) {
            'Darwin' => ['pbcopy'],
            'Windows' => ['clip'],
            default => ['wl-copy', 'xclip -selection clipboard', 'xsel --clipboard --input'],
        };

        foreach ($candidates as $command) {
            $binary = strtok($command, ' ');
            if (! $this->commandExists($binary)) {
                continue;
            }

            $process = proc_open($command, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
            if (! is_resource($process)) {
                continue;
            }

            fwrite($pipes[0], $text);
            fclose($pipes[0]);
            fclose($pipes[1]);
            fclose($pipes[2]);

            if (proc_close($process) === 0) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check whether an executable is available on PATH.
     */
    private function commandExists(string $binary): bool
    {
        $probe = PHP_OS_FAMILY === 'Windows' ? "where {$binary}" : "command -v {$binary}";

        exec($probe.' 2>&1', $output, $exitCode);

        return $exitCode === 0;
    }
}
