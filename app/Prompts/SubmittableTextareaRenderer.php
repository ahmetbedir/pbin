<?php

namespace App\Prompts;

use Laravel\Prompts\TextareaPrompt;
use Laravel\Prompts\Themes\Default\TextareaPromptRenderer;

/**
 * Same as the default textarea renderer, but the hint reflects that an empty
 * line submits (see {@see SubmittableTextareaPrompt}).
 */
class SubmittableTextareaRenderer extends TextareaPromptRenderer
{
    private const SUBMIT_HINT = 'Enter on an empty line to submit (or Ctrl+D)';

    public function __invoke(TextareaPrompt $prompt): string
    {
        $prompt->width = $prompt->terminal()->cols() - 8;

        return match ($prompt->state) {
            'submit' => $this
                ->box(
                    $this->dim($this->truncate($prompt->label, $prompt->width)),
                    implode(PHP_EOL, $prompt->lines()),
                ),

            'cancel' => $this
                ->box(
                    $this->truncate($prompt->label, $prompt->width),
                    implode(PHP_EOL, array_map(fn ($line) => $this->strikethrough($this->dim($line)), $prompt->lines())),
                    color: 'red',
                )
                ->error($prompt->cancelMessage),

            'error' => $this
                ->box(
                    $this->truncate($prompt->label, $prompt->width),
                    $this->renderText($prompt),
                    color: 'yellow',
                    info: self::SUBMIT_HINT,
                )
                ->warning($this->truncate($prompt->error, $prompt->terminal()->cols() - 5)),

            default => $this
                ->box(
                    $this->cyan($this->truncate($prompt->label, $prompt->width)),
                    $this->renderText($prompt),
                    info: self::SUBMIT_HINT,
                )
                ->when(
                    $prompt->hint,
                    fn () => $this->hint($prompt->hint),
                    fn () => $this->newLine() // Space for errors
                )
        };
    }
}
