<?php

namespace App\Providers;

use App\Prompts\SubmittableTextareaPrompt;
use App\Prompts\SubmittableTextareaRenderer;
use Illuminate\Support\ServiceProvider;
use Laravel\Prompts\Prompt;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Register a renderer for our custom textarea prompt. Every other
        // prompt falls back to the default theme's renderers automatically.
        Prompt::addTheme('pbin', [
            SubmittableTextareaPrompt::class => SubmittableTextareaRenderer::class,
        ]);
        Prompt::theme('pbin');
    }

    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }
}
