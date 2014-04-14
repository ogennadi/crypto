;; Copyright 2012-2014 Ryan Culpepper
;; Copyright 2007-2009 Dimitris Vyzovitis <vyzo at media.mit.edu>
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
         racket/class
         "../common/interfaces.rkt"
         "../common/common.rkt"
         "../common/error.rkt"
         "ffi.rkt")
(provide (all-defined-out))

;; ============================================================

(define libcrypto-digest-impl%
  (class* impl-base% (digest-impl<%>)
    (init-field md)    ;; EVP_MD
    (define size (EVP_MD_size md))
    (define hmac-impl #f)
    (super-new)

    (define/public (get-size) size)
    (define/public (get-block-size) (EVP_MD_block_size md))

    (define/public (new-ctx)
      (let ([ctx (EVP_MD_CTX_create)])
        (EVP_DigestInit_ex ctx md)
        (new libcrypto-digest-ctx% (impl this) (ctx ctx))))

    (define/public (get-hmac-impl)
      (unless hmac-impl
        (set! hmac-impl (new libcrypto-hmac-impl% (digest this))))
      hmac-impl)

    ;; ----

    ;; FIXME: tried to use EVP_Digest but got segfault
    (define/public (can-digest-buffer!?) #f)
    (define/public (digest-buffer! buf start end outbuf outstart) (void))

    (define/public (can-hmac-buffer!?) #t)
    (define/public (hmac-buffer! key buf start end outbuf outstart)
      (check-input-range buf start end)
      (check-output-range outbuf outstart (+ outstart size))
      (HMAC md key (bytes-length key) (ptr-add buf start) (- end start)
            (ptr-add outbuf outstart))
      (void))
    ))

(define libcrypto-digest-ctx%
  (class* ctx-base% (digest-ctx<%>)
    (init-field ctx)
    (inherit-field impl)
    (super-new)

    (define/public (update buf start end)
      (check-input-range buf start end)
      (void (EVP_DigestUpdate ctx (ptr-add buf start) (- end start))))

    (define/public (final! buf start end)
      (let ([size (send impl get-size)])
        (check-output-range buf start end size)
        (EVP_DigestFinal_ex ctx (ptr-add buf start))
        (EVP_DigestInit_ex ctx (get-field md impl))
        size))

    (define/public (copy)
      (let ([other (send impl new-ctx)])
        (EVP_MD_CTX_copy_ex (get-field ctx other) ctx)
        other))
    ))

;; ============================================================

(define libcrypto-hmac-impl%
  (class* object% (hmac-impl<%>)
    (init-field digest)
    (super-new)
    (define/public (get-spec) `(hmac ,(send digest get-spec)))
    (define/public (get-factory) (send digest get-factory))
    (define/public (get-digest) digest)
    (define/public (new-ctx key)
      (let ([ctx (HMAC_CTX_new)])
        (HMAC_Init_ex ctx key (bytes-length key) (get-field md digest))
        (new libcrypto-hmac-ctx% (impl digest) (ctx ctx))))
    ))

(define libcrypto-hmac-ctx%
  (class* ctx-base% (digest-ctx<%>)
    (init-field ctx)
    (inherit-field impl)
    (super-new)

    (define/public (update buf start end)
      (check-input-range buf start end)
      (void (HMAC_Update ctx (ptr-add buf start) (- end start))))

    (define/public (final! buf start end)
      (let ([size (send impl get-size)])
        (check-output-range buf start end size)
        (HMAC_Final ctx (ptr-add buf start))
        (HMAC_Init_ex ctx #f 0 (get-field md impl))
        size))

    (define/public (copy)
      (let ([ctx2 (HMAC_CTX_new)])
        (HMAC_CTX_copy ctx2 ctx)
        (new libcrypto-hmac-ctx% (impl impl) (ctx ctx2))))
    ))