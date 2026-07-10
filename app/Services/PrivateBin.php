<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use InvalidArgumentException;
use RuntimeException;

/**
 * Minimal client for the PrivateBin v2 API.
 *
 * PrivateBin is zero-knowledge: the server only ever stores ciphertext. All
 * encryption happens here, client-side, mirroring the reference implementation
 * in PrivateBin's js/privatebin.js:
 *
 *   - a random 256-bit master key is generated and never sent to the server
 *   - PBKDF2-SHA256 (100k iterations) derives the AES key from the master key
 *     (optionally concatenated with a user password) and an 8-byte salt
 *   - the paste is JSON-wrapped, raw-DEFLATE compressed, then AES-256-GCM
 *     encrypted with the JSON-encoded adata as the GCM additional data
 *   - the master key is base58-encoded and lives only in the URL fragment
 */
class PrivateBin
{
    private const ITERATIONS = 100000;

    private const KEY_SIZE = 256;   // bits

    private const TAG_SIZE = 128;   // bits

    private const BASE58_ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    public function __construct(private readonly string $baseUrl) {}

    /**
     * Encrypt and upload a paste, returning the shareable URL (with the key in
     * the fragment) and the deletion URL.
     *
     * @return array{view_url: string, delete_url: string, id: string}
     */
    public function create(
        string $content,
        string $expiry = '1day',
        ?string $password = null,
        bool $burnAfterReading = false,
        string $format = 'plaintext',
        bool $openDiscussion = false,
    ): array {
        // PrivateBin treats these as mutually exclusive and the server rejects
        // pastes that set both.
        if ($burnAfterReading && $openDiscussion) {
            throw new InvalidArgumentException('Burn-after-reading and open discussion cannot both be enabled.');
        }

        $key = random_bytes(32);
        $iv = random_bytes(16);
        $salt = random_bytes(8);
        $password ??= '';

        // adata: [encodedSpec, format, openDiscussion, burnAfterReading].
        // iv/salt are base64 in adata; the raw bytes are used for crypto.
        $adata = [
            [
                base64_encode($iv),
                base64_encode($salt),
                self::ITERATIONS,
                self::KEY_SIZE,
                self::TAG_SIZE,
                'aes',
                'gcm',
                'zlib',
            ],
            $format,
            $openDiscussion ? 1 : 0,
            $burnAfterReading ? 1 : 0,
        ];

        // The GCM additional data is the JSON string of adata. It must match
        // byte-for-byte what the browser reconstructs, so slashes stay
        // unescaped (JSON.stringify never escapes them).
        $aad = json_encode($adata, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        // Message: JSON-wrapped, then raw-DEFLATE compressed ("zlib" mode).
        $message = json_encode(['paste' => $content], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        $compressed = gzdeflate($message);
        if ($compressed === false) {
            throw new RuntimeException('Failed to compress paste content.');
        }

        // PBKDF2 input = master key concatenated with the password bytes.
        $derivedKey = hash_pbkdf2('sha256', $key.$password, $salt, self::ITERATIONS, self::KEY_SIZE / 8, true);

        $tag = '';
        $ciphertext = openssl_encrypt(
            $compressed,
            'aes-256-gcm',
            $derivedKey,
            OPENSSL_RAW_DATA,
            $iv,
            $tag,
            $aad,
            self::TAG_SIZE / 8,
        );
        if ($ciphertext === false) {
            throw new RuntimeException('Encryption failed: '.openssl_error_string());
        }

        // WebCrypto returns ciphertext||tag; PrivateBin base64-encodes that.
        $ct = base64_encode($ciphertext.$tag);

        $response = Http::withHeaders(['X-Requested-With' => 'JSONHttpRequest'])
            ->acceptJson()
            ->asJson()
            ->post($this->baseUrl.'/', [
                'v' => 2,
                'adata' => $adata,
                'ct' => $ct,
                'meta' => ['expire' => $expiry],
            ]);

        $body = $response->json();

        if (! is_array($body) || ($body['status'] ?? 1) !== 0) {
            $message = is_array($body) ? ($body['message'] ?? 'unknown error') : 'invalid response';
            throw new RuntimeException("PrivateBin rejected the paste: {$message}");
        }

        $id = $body['id'];
        $deleteToken = $body['deletetoken'] ?? '';
        $fragment = $this->base58encode($key);

        return [
            'id' => $id,
            'view_url' => "{$this->baseUrl}/?{$id}#{$fragment}",
            'delete_url' => "{$this->baseUrl}/?pasteid={$id}&deletetoken={$deleteToken}",
        ];
    }

    /**
     * Base58 (Bitcoin alphabet) encode a raw byte string.
     */
    private function base58encode(string $data): string
    {
        if ($data === '') {
            return '';
        }

        $bytes = array_values(unpack('C*', $data));
        $length = count($bytes);

        $leadingZeros = 0;
        while ($leadingZeros < $length && $bytes[$leadingZeros] === 0) {
            $leadingZeros++;
        }

        $encoded = '';
        $start = $leadingZeros;
        while ($start < $length) {
            $remainder = 0;
            for ($i = $start; $i < $length; $i++) {
                $accumulator = ($remainder << 8) + $bytes[$i];
                $bytes[$i] = intdiv($accumulator, 58);
                $remainder = $accumulator % 58;
                if ($bytes[$i] === 0 && $i === $start) {
                    $start++;
                }
            }
            $encoded = self::BASE58_ALPHABET[$remainder].$encoded;
        }

        return str_repeat(self::BASE58_ALPHABET[0], $leadingZeros).$encoded;
    }
}
