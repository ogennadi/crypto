;; Copyright 2013-2014 Ryan Culpepper
;; 
;; This library is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Lesser General Public License as published
;; by the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; 
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Lesser General Public License for more details.
;; 
;; You should have received a copy of the GNU Lesser General Public License
;; along with this library.  If not, see <http://www.gnu.org/licenses/>.

#lang racket/base
(require ffi/unsafe
         ffi/unsafe/alloc
         (only-in '#%foreign ffi-obj)
         ffi/unsafe/define
         "../gmp/ffi.rkt")
(provide (protect-out (all-defined-out)))

(define libnettle (ffi-lib "libnettle" '("4" #f)))

(define-ffi-definer define-nettle libnettle
  #:default-make-fail make-not-available)

;; ----

(define-cpointer-type _HASH_CTX)

(define _nettle_hash_init_func
  (_fun _HASH_CTX -> _void))
(define _nettle_hash_update_func
  (_fun _HASH_CTX _uint _pointer -> _void))
(define _nettle_hash_digest_func
  (_fun _HASH_CTX _uint _pointer -> _void))

(define-cstruct _nettle_hash
  ([name         _string/utf-8]
   [context_size _uint]
   [digest_size  _uint]
   [block_size   _uint]
   [init         _nettle_hash_init_func]
   [update       _nettle_hash_update_func]
   [digest       _nettle_hash_digest_func]))

;; struct nettle_hash *nettle_hashes[], array terminated by NULL
(define nettle_hashes (ffi-obj #"nettle_hashes" libnettle))

(define nettle-hashes
  (let ([ptr nettle_hashes])
    (let loop ([i 0])
      (let ([next (ptr-ref ptr _nettle_hash-pointer/null i)])
        (if next
            (cons (list (nettle_hash-name next) next)
                  (loop (add1 i)))
            null)))))

;; ----

(define-nettle nettle_hmac_set_key
  (_fun (outer inner state hash key) ::
        (outer : _HASH_CTX)
        (inner : _HASH_CTX)
        (state : _HASH_CTX)
        (hash  : _nettle_hash-pointer)
        (keylen : _uint = (bytes-length key))
        (key   : _pointer)
        -> _void))

(define-nettle nettle_hmac_update
  (_fun (state hash inbuf inlen) ::
        (state : _HASH_CTX)
        (hash  : _nettle_hash-pointer)
        (inlen : _uint)
        (inbuf : _pointer)
        -> _void))

(define-nettle nettle_hmac_digest
  (_fun (outer inner state hash outbuf outlen) ::
        (outer  : _HASH_CTX)
        (inner  : _HASH_CTX)
        (state  : _HASH_CTX)
        (hash   : _nettle_hash-pointer)
        (outlen : _uint)
        (outbuf : _pointer)
        -> _void))

;; ----

(define-cpointer-type _CIPHER_CTX)

(define _nettle_set_key_func
  (_fun _CIPHER_CTX _uint _pointer -> _void))

(define _nettle_crypt_func
  (_fun _CIPHER_CTX _uint _pointer _pointer -> _void))

(define-cstruct _nettle_cipher
  ([name            _string/utf-8]
   [context_size    _uint]
   [block_size      _uint]
   [key_size        _uint]
   [set_encrypt_key _nettle_set_key_func]
   [set_decrypt_key _nettle_set_key_func]
   [encrypt         _nettle_crypt_func]
   [decrypt         _nettle_crypt_func]))

;; Want to create cipher records for "irregular" ciphers; easiest way
;; to handle mix of static, foreign-allocated records and dynamic,
;; racket-allocated records is to copy.

(struct nettle-cipher (name
                       context-size block-size key-size
                       set-encrypt-key set-decrypt-key
                       encrypt decrypt
                       extras))

;; struct nettle_cipher *nettle_ciphers[], array terminated by NULL
(define nettle_ciphers (ffi-obj #"nettle_ciphers" libnettle))

(define nettle-regular-ciphers
  (let ([ptr nettle_ciphers])
    (let loop ([i 0])
      (let ([next (ptr-ref ptr _nettle_cipher-pointer/null i)])
        (if next
            (cons (nettle-cipher (nettle_cipher-name next)
                                 (nettle_cipher-context_size next)
                                 (max 1 (nettle_cipher-block_size next))
                                 (nettle_cipher-key_size next)
                                 (nettle_cipher-set_encrypt_key next)
                                 (nettle_cipher-set_decrypt_key next)
                                 (nettle_cipher-encrypt next)
                                 (nettle_cipher-decrypt next)
                                 null)
                  (loop (add1 i)))
            null)))))

;; nettle_ciphers omits ciphers with any irregularity; create entries for them too

(define BLOWFISH_ROUNDS 16)
(define BLOWFISH_CONTEXT_SIZE (+ (* 4 4 256) (* 4 (+ 2 BLOWFISH_ROUNDS))))
(define BLOWFISH_BLOCK_SIZE 8)
(define BLOWFISH_KEY_SIZE 16) ;; reasonable default
(define-nettle nettle_blowfish_set_key _nettle_set_key_func)
(define-nettle nettle_blowfish_encrypt _nettle_crypt_func #:fail (lambda () #f))
(define-nettle nettle_blowfish_decrypt _nettle_crypt_func #:fail (lambda () #f))

(define blowfish-cipher
  (and nettle_blowfish_encrypt
       (nettle-cipher "blowfish"
                      BLOWFISH_CONTEXT_SIZE BLOWFISH_BLOCK_SIZE BLOWFISH_KEY_SIZE
                      nettle_blowfish_set_key nettle_blowfish_set_key
                      nettle_blowfish_encrypt nettle_blowfish_decrypt
                      null)))

(define SALSA20_CONTEXT_SIZE (* 4 16))
(define SALSA20_KEY_SIZE 32)
(define SALSA20_BLOCK_SIZE 64)
(define SALSA20_IV_SIZE 8)
(define-nettle nettle_salsa20_set_key _nettle_set_key_func)
(define-nettle nettle_salsa20_set_iv (_fun _CIPHER_CTX _pointer -> _void))
(define-nettle nettle_salsa20_crypt _nettle_crypt_func #:fail (lambda () #f))
(define-nettle nettle_salsa20r12_crypt _nettle_crypt_func #:fail (lambda () #f))

(define salsa20-cipher
  (and nettle_salsa20_crypt
       (nettle-cipher "salsa20"
                      SALSA20_CONTEXT_SIZE SALSA20_BLOCK_SIZE SALSA20_KEY_SIZE
                      nettle_salsa20_set_key nettle_salsa20_set_key
                      nettle_salsa20_crypt nettle_salsa20_crypt
                      `((set-iv ,nettle_salsa20_set_iv)))))

(define salsa20r12-cipher
  (and nettle_salsa20r12_crypt
       (nettle-cipher "salsa20r12"
                      SALSA20_CONTEXT_SIZE SALSA20_BLOCK_SIZE SALSA20_KEY_SIZE
                      nettle_salsa20_set_key nettle_salsa20_set_key
                      nettle_salsa20r12_crypt nettle_salsa20r12_crypt
                      `((set-iv ,nettle_salsa20_set_iv)))))

(define nettle-all-ciphers
  (let* ([more-ciphers
          (append nettle-regular-ciphers
                  (filter values
                          (list blowfish-cipher
                                salsa20-cipher
                                salsa20r12-cipher)))])
    (for/list ([cipher (in-list more-ciphers)])
      (list (nettle-cipher-name cipher) cipher))))

;; ----

(define-nettle nettle_cbc_encrypt
  (_fun (ctx     : _CIPHER_CTX)
        (encrypt : _nettle_crypt_func)
        (blksize : _uint)
        (iv      : _pointer)
        (length  : _uint)
        (dst     : _pointer)
        (src     : _pointer)
        -> _void))

(define-nettle nettle_cbc_decrypt
  (_fun (ctx     : _CIPHER_CTX)
        (decrypt : _nettle_crypt_func)
        (blksize : _uint)
        (iv      : _pointer)
        (length  : _uint)
        (dst     : _pointer)
        (src     : _pointer)
        -> _void))

(define-nettle nettle_ctr_crypt
  (_fun (ctx     : _CIPHER_CTX)
        (crypt   : _nettle_crypt_func)
        (blksize : _uint)
        (ctr     : _pointer)
        (length  : _uint)
        (dst     : _pointer)
        (src     : _pointer)
        -> _void))

(define GCM_BLOCK_SIZE 16)
(define GCM_IV_SIZE (- GCM_BLOCK_SIZE 4))
(define GCM_TABLE_BITS 8)
;; gcm_block = GCM_BLOCK_SIZE bytes, ulong-aligned
;; gcm_key = array of 1<<GCM_TABLE_BITS gcm_blocks
;; gcm_ctx = { 3 * gcm_block ; 2 * uint64 }
(define GCM_KEY_SIZE (* GCM_BLOCK_SIZE (expt 2 GCM_TABLE_BITS)))
(define GCM_CTX_SIZE (+ (* 3 GCM_BLOCK_SIZE) (* 2 (ctype-sizeof _uint64))))

(define-cpointer-type _gcm_key)
(define-cpointer-type _gcm_ctx)

(define-nettle nettle_gcm_set_key
  (_fun _gcm_key _CIPHER_CTX _nettle_crypt_func -> _void))
(define-nettle nettle_gcm_set_iv
  (_fun _gcm_ctx _gcm_key _uint _pointer -> _void))

(define-nettle nettle_gcm_update
  ;; add AAD, all but last must be block-size multiple
  (_fun _gcm_ctx _gcm_key _uint _pointer -> _void))

(define-nettle nettle_gcm_encrypt
  ;; add plaintext, all but last must be block-size multiple
  (_fun _gcm_ctx _gcm_key _CIPHER_CTX _nettle_crypt_func _uint _pointer _pointer -> _void))
(define-nettle nettle_gcm_decrypt
  ;; add ciphertext, all but last must be block-size multiple
  ;; use cipher's *encrypt* func for _nettle_crypt_func argument
  (_fun _gcm_ctx _gcm_key _CIPHER_CTX _nettle_crypt_func _uint _pointer _pointer -> _void))

(define-nettle nettle_gcm_digest
  ;; get auth tag; length usually GCM_BLOCK_SIZE, but can be shorter
  (_fun _gcm_ctx _gcm_key _CIPHER_CTX _nettle_crypt_func _uint _pointer -> _void))

;; ----

(define-nettle nettle_pbkdf2
  (_fun (mac_ctx update_func digest_func digest_size iterations salt out) ::
        (mac_ctx : _HASH_CTX) ;; 3 * digest_size !
        (update_func : _fpointer)
        (digest_func : _fpointer)
        (digest_size : _uint)
        (iterations : _uint)
        (salt_length : _uint = (bytes-length salt))
        (salt : _bytes)
        (outlen : _uint = (bytes-length out))
        (out : _bytes)
        -> _void))

;; ----

(define YARROW256_CTX_SIZE 496)
(define YARROW_SOURCE_SIZE 12)
(define YARROW256_SEED_FILE_SIZE 32)   ;; = 2 * AES_BLOCK_SIZE

(define-cpointer-type _yarrow256_ctx)
(define-cpointer-type _yarrow_source)

(define-nettle nettle_yarrow256_init
  (_fun _yarrow256_ctx _uint _yarrow_source/null
        -> _void))

(define-nettle nettle_yarrow256_seed
  (_fun (ctx buf) ::
        (ctx : _yarrow256_ctx)
        (len : _uint = (bytes-length buf))
        (buf : _bytes)
        -> _void))

(define-nettle nettle_yarrow256_update
  (_fun (ctx src entropy buf) ::
        (ctx : _yarrow256_ctx)
        (src : _uint)
        (entropy : _uint)
        (len : _uint = (bytes-length buf))
        (buf : _bytes)
        -> _int))

(define-nettle nettle_yarrow256_random
  (_fun _yarrow256_ctx _uint _pointer
        -> _void))

(define-nettle nettle_yarrow256_is_seeded
  (_fun _yarrow256_ctx -> _bool))

(define-nettle nettle_yarrow256_needed_sources
  (_fun _yarrow256_ctx -> _uint))

(define-nettle nettle_yarrow256_fast_reseed
  (_fun _yarrow256_ctx -> _void))
(define-nettle nettle_yarrow256_slow_reseed
  (_fun _yarrow256_ctx -> _void))

;; ----

(define-ffi-definer define-nettleHW (ffi-lib "libhogweed"))

(define-cstruct _rsa_public_key_struct
  ([size _uint]  ;; size of modulo in octets, also size in sigs
   [n    _mpz_struct]
   [e    _mpz_struct]))

(define-cstruct _rsa_private_key_struct
  ([size _uint]
   [d    _mpz_struct]
   [p    _mpz_struct]
   [q    _mpz_struct]
   [a    _mpz_struct]
   [b    _mpz_struct]
   [c    _mpz_struct]))

(define _rsa_public_key _rsa_public_key_struct-pointer)
(define _rsa_private_key _rsa_private_key_struct-pointer)

(define-nettleHW nettle_rsa_public_key_init
  (_fun _rsa_public_key -> _void))
(define-nettleHW nettle_rsa_private_key_init
  (_fun _rsa_private_key -> _void))

(define-nettleHW nettle_rsa_public_key_clear
  (_fun _rsa_public_key -> _void)
  #:wrap (deallocator))
(define-nettleHW nettle_rsa_private_key_clear
  (_fun _rsa_private_key -> _void)
  #:wrap (deallocator))

(define new-rsa_public_key
  ((allocator nettle_rsa_public_key_clear)
   (lambda ()
     (define k (malloc _rsa_public_key_struct 'atomic-interior))
     (cpointer-push-tag! k rsa_public_key_struct-tag)
     (nettle_rsa_public_key_init k)
     k)))

(define new-rsa_private_key
  ((allocator nettle_rsa_private_key_clear)
   (lambda ()
     (define k (malloc _rsa_private_key_struct 'atomic-interior))
     (cpointer-push-tag! k rsa_private_key_struct-tag)
     (nettle_rsa_private_key_init k)
     k)))

(define-nettleHW nettle_rsa_public_key_prepare
  (_fun _rsa_public_key -> _void))
(define-nettleHW nettle_rsa_private_key_prepare
  (_fun _rsa_private_key -> _void))

(define-nettleHW nettle_rsa_md5_sign_digest (_fun _rsa_private_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha1_sign_digest (_fun _rsa_private_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha256_sign_digest (_fun _rsa_private_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha512_sign_digest (_fun _rsa_private_key _pointer _mpz_t -> _bool))

(define-nettleHW nettle_rsa_md5_verify_digest (_fun _rsa_public_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha1_verify_digest (_fun _rsa_public_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha256_verify_digest (_fun _rsa_public_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha512_verify_digest (_fun _rsa_public_key _pointer _mpz_t -> _bool))

(define-nettle yarrow_random _fpointer
  #:c-id nettle_yarrow256_random)

(define-nettleHW nettle_rsa_generate_keypair
  (_fun _rsa_public_key
        _rsa_private_key
        (random-ctx : _pointer)
        (_fpointer = yarrow_random)
        (_pointer = #f)
        (_fpointer = #f)
        (n_size : _uint)
        (e_size : _uint)
        -> _int))

(define-nettleHW nettle_rsa_encrypt  ;; PKCS1 v1.5 padding
  (_fun (pub random-ctx cleartext ciphertext) ::
        (pub : _rsa_public_key)
        (random-ctx : _pointer)
        (_fpointer = yarrow_random)
        (_uint = (bytes-length cleartext))
        (cleartext : _bytes)
        (ciphertext : _mpz_t)
        -> _bool))

(define-nettleHW nettle_rsa_decrypt ;; PKCS1 v1.5 padding
  (_fun (priv cleartext ciphertext) ::
        (priv : _rsa_private_key)
        (len : (_ptr io _uint) = (bytes-length cleartext))
        (cleartext : _bytes)
        (ciphertext : _mpz_t)
        -> (result : _bool)
        -> (and result len)))

;; ----

(define-cstruct _dsa_public_key_struct
  ([p    _mpz_struct]
   [q    _mpz_struct]
   [g    _mpz_struct]
   [y    _mpz_struct]))

(define-cstruct _dsa_private_key_struct
  ([x    _mpz_struct]))

(define-cstruct _dsa_signature_struct
  ([r    _mpz_struct]
   [s    _mpz_struct]))

(define _dsa_public_key _dsa_public_key_struct-pointer)
(define _dsa_private_key _dsa_private_key_struct-pointer)
(define _dsa_signature _dsa_signature_struct-pointer)

(define-nettleHW nettle_dsa_public_key_init
  (_fun _dsa_public_key -> _void))
(define-nettleHW nettle_dsa_private_key_init
  (_fun _dsa_private_key -> _void))
(define-nettleHW nettle_dsa_signature_init
  (_fun _dsa_signature -> _void))

(define-nettleHW nettle_dsa_public_key_clear
  (_fun _dsa_public_key -> _void)
  #:wrap (deallocator))
(define-nettleHW nettle_dsa_private_key_clear
  (_fun _dsa_private_key -> _void)
  #:wrap (deallocator))
(define-nettleHW nettle_dsa_signature_clear
  (_fun _dsa_signature -> _void)
  #:wrap (deallocator))

(define new-dsa_public_key
  ((allocator nettle_dsa_public_key_clear)
   (lambda ()
     (define k (malloc _dsa_public_key_struct 'atomic-interior))
     (cpointer-push-tag! k mpz_struct-tag) ;; FIXME: why necessary???
     (cpointer-push-tag! k dsa_public_key_struct-tag)
     (nettle_dsa_public_key_init k)
     k)))

(define new-dsa_private_key
  ((allocator nettle_rsa_private_key_clear)
   (lambda ()
     (define k (malloc _dsa_private_key_struct 'atomic-interior))
     (cpointer-push-tag! k mpz_struct-tag) ;; FIXME: why necessary???
     (cpointer-push-tag! k dsa_private_key_struct-tag)
     (nettle_dsa_private_key_init k)
     k)))

(define new-dsa_signature
  ((allocator nettle_dsa_signature_clear)
   (lambda ()
     (define k (malloc _dsa_signature_struct 'atomic-interior))
     (cpointer-push-tag! k mpz_struct-tag) ;; FIXME: why necessary???
     (cpointer-push-tag! k dsa_signature_struct-tag)
     (nettle_dsa_signature_init k)
     k)))

(define _dsa_sign_digest
  (_fun (pub : _dsa_public_key)
        (priv : _dsa_private_key)
        (random-ctx : _pointer)
        (_fpointer = yarrow_random)
        (dgst : _bytes)
        (sig : _dsa_signature)
        -> _bool))

(define _dsa_verify_digest
  (_fun (pub : _dsa_public_key)
        (dgst : _bytes)
        (sig : _dsa_signature)
        -> _bool))

(define-nettleHW nettle_dsa_sha1_sign_digest _dsa_sign_digest)
(define-nettleHW nettle_dsa_sha256_sign_digest _dsa_sign_digest)

(define-nettleHW nettle_dsa_sha1_verify_digest _dsa_verify_digest)
(define-nettleHW nettle_dsa_sha256_verify_digest _dsa_verify_digest)

(define-nettleHW nettle_dsa_generate_keypair
  (_fun _dsa_public_key
        _dsa_private_key
        (random-ctx : _pointer)
        (_fpointer = yarrow_random)
        (_pointer = #f)
        (_fpointer = #f)
        (p-bits : _uint) ;; eg, 2048
        (q-bits : _uint) ;; 256
        -> _bool))