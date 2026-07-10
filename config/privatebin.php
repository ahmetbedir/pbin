<?php

return [
    /*
    |--------------------------------------------------------------------------
    | PrivateBin instance URL
    |--------------------------------------------------------------------------
    |
    | Intentionally NOT hardcoded — the instance URL is private and must not
    | live in (public) source. It is set per-user on first run and stored in
    | ~/.pbin/config.json (see App\Support\UserConfig). An optional
    | PRIVATEBIN_URL env var can override it for CI/testing.
    |
    */
    'url' => env('PRIVATEBIN_URL'),

    /*
    |--------------------------------------------------------------------------
    | Default expiry
    |--------------------------------------------------------------------------
    |
    | One of: 5min, 10min, 1hour, 1day, 1week, 1month, 1year, never.
    | Must be enabled on the target instance.
    |
    */
    'default_expiry' => env('PRIVATEBIN_EXPIRY', '1day'),
];
