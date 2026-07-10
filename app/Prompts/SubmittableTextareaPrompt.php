<?php

namespace App\Prompts;

use Closure;
use Laravel\Prompts\Key;
use Laravel\Prompts\TextareaPrompt;

/**
 * A textarea that also submits when Enter is pressed on an empty line.
 *
 * Terminals cannot distinguish Ctrl/Cmd+Enter from a plain Enter, so we keep
 * Enter as the newline key and treat an Enter on a blank line as the "send"
 * gesture (double Enter). Ctrl+D still submits too, inherited from the parent.
 */
class SubmittableTextareaPrompt extends TextareaPrompt
{
    public function __construct(
        string $label,
        string $placeholder = '',
        string $default = '',
        bool|string $required = false,
        mixed $validate = null,
        string $hint = '',
        int $rows = 5,
        ?Closure $transform = null,
    ) {
        parent::__construct($label, $placeholder, $default, $required, $validate, $hint, $rows, $transform);

        // Registered after TypedValue's handler, so by the time this runs the
        // newline for the current Enter has already been inserted.
        $this->on('key', function (string $key): void {
            if ($key !== Key::ENTER) {
                return;
            }

            // Index of the newline the parent just inserted.
            $insertedIndex = $this->cursorPosition - 1;
            if ($insertedIndex < 0) {
                return;
            }

            $onEmptyLine = $insertedIndex === 0
                || mb_substr($this->typedValue, $insertedIndex - 1, 1) === "\n";

            if (! $onEmptyLine) {
                return;
            }

            // Drop the "send" newline plus any trailing blank lines, then submit
            // the cleaned value. If it is empty, `required` validation re-prompts.
            $withoutNewline = mb_substr($this->typedValue, 0, $insertedIndex)
                .mb_substr($this->typedValue, $insertedIndex + 1);
            $this->typedValue = rtrim($withoutNewline, "\n");
            $this->cursorPosition = mb_strlen($this->typedValue);

            $this->submit();
        });
    }
}
