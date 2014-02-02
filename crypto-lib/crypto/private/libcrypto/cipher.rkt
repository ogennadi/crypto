;; Copyright 2012-2013 Ryan Culpepper
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
         racket/match
         "../common/interfaces.rkt"
         "../common/catalog.rkt"
         "../common/common.rkt"
         "../common/error.rkt"
         "ffi.rkt")
(provide (all-defined-out))

(define libcrypto-cipher-impl%
  (class* impl-base% (cipher-impl<%>)
    (init-field cipher) ;; EVP_CIPHER
    (inherit-field spec)
    (super-new)
    (define-values (block-size key-size iv-size)
      (match (ptr-ref cipher (_list-struct _int _int _int _int))
        [(list _ size keylen ivlen)
         (values size keylen ivlen)]))
    (let ()
      (define (check what value expected)
        (unless (= value expected)
          (error 'cipher-impl%
                 "internal error: inconsistent ~a\n  cipher: ~e\n  expected: ~e\n  got: ~e"
                 what spec value expected)))
      (check "block size" block-size (cipher-spec-block-size spec))
      (check "IV size" iv-size (cipher-spec-iv-size spec)))

    (define/public (get-block-size) block-size)
    (define/public (get-iv-size) iv-size)
    (define/public (is-ae?) (and (memq (cadr spec) '(gcm ccm))))

    (define/public (new-ctx key iv enc? pad?)
      (check-key-size spec (bytes-length key))
      (check-iv-size spec iv-size iv)
      (let ([ctx (EVP_CIPHER_CTX_new)])
        (EVP_CipherInit_ex ctx cipher #f #f enc?)
        (EVP_CIPHER_CTX_set_key_length ctx (bytes-length key))
        (EVP_CIPHER_CTX_set_padding ctx (and pad? (cipher-spec-uses-padding? spec)))
        (define ivlen (if iv (bytes-length iv) 0))
        (case (cadr spec)
          [(gcm) (EVP_CIPHER_CTX_ctrl ctx EVP_CTRL_GCM_SET_IVLEN ivlen #f)]
          [(ccm) (EVP_CIPHER_CTX_ctrl ctx EVP_CTRL_CCM_SET_IVLEN ivlen #f)]
          [else (void)])
        (EVP_CipherInit_ex ctx cipher key iv enc?)
        (new libcrypto-cipher-ctx% (impl this) (ctx ctx) (encrypt? enc?))))
    ))

;; Conflicting notes about GCM mode:
;; - Must set AAD with NULL output buffer; MUST set, even if 0-length (use #"")
;;   See http://incog-izick.blogspot.com/2011/08/using-openssl-aes-gcm.html
;; - No, don't, if using EVP_CipherInit_ex
;;   See http://stackoverflow.com/questions/12153009/


(define libcrypto-cipher-ctx%
  (class* ctx-base% (cipher-ctx<%>)
    (init-field ctx encrypt?)
    (inherit-field impl)
    (super-new)

    ;; State is nat
    ;;  0 - needs tag set (decrypting)
    ;;  1 - ready for AAD
    ;;  2 - AAD done, ready for plaintext
    ;;  3 - finalized but tag available (encrypting)
    ;;  4 - closed
    (define state
      (cond [(and (not encrypt?) (send impl is-ae?)) 0]
            [else 1]))

    (define/private (state-error state-desc)
      (crypto-error "cipher context sequence error\n  state: ~a" state-desc))

    (define/private (check-state ok-states #:next [new-state #f])
      (if (memq state ok-states)
          (when new-state (unless (= state new-state) (set! state new-state)))
          (case state
            [(0) (state-error "AE decryption context needs authentication tag")]
            [(1) (void)]
            [(2) (state-error "cannot add additionally authenticated data after plaintext")]
            [(3 4) (err/cipher-closed)])))

    (define/public (get-encrypt?) encrypt?)

    (define/public (update! inbuf instart inend outbuf outstart outend)
      (check-state '(1 2) #:next 2)
      (unless ctx (err/cipher-closed))
      (check-input-range inbuf instart inend)
      (check-output-range outbuf outstart outend (maxlen (- inend instart)))
      (update* inbuf instart inend outbuf outstart outend))

    (define/public (update-AAD inbuf instart inend)
      (check-state '(1))
      (unless ctx (err/cipher-closed))
      (check-input-range inbuf instart inend)
      (update* inbuf instart inend #f 0 0))

    (define/private (update* inbuf instart inend outbuf outstart outend)
      (EVP_CipherUpdate ctx (ptr-add outbuf outstart)
                        (ptr-add inbuf instart)
                        (- inend instart)))

    (define/public (final! outbuf outstart outend)
      (check-state '(1 2) #:next 3)
      (unless ctx (err/cipher-closed))
      (check-output-range outbuf outstart outend (maxlen 0))
      (begin0 (or (EVP_CipherFinal_ex ctx (ptr-add outbuf outstart))
                  (if (send impl is-ae?)
                      (crypto-error "authenticated decryption failed")
                      (crypto-error "decryption failed")))
        (unless (send impl is-ae?) (close))))

    (define/public (set-auth-tag tag)
      (check-state '(0) #:next 1)
      (unless ctx (err/cipher-closed))
      (EVP_CIPHER_CTX_ctrl ctx EVP_CTRL_GCM_SET_TAG (bytes-length tag) tag))

    (define/public (get-auth-tag taglen)
      (unless encrypt? (crypto-error "cannot get authentication tag for decryption context"))
      (check-state '(3))
      (unless ctx (err/cipher-closed))
      (define tagbuf (make-bytes taglen))
      (EVP_CIPHER_CTX_ctrl ctx EVP_CTRL_GCM_GET_TAG taglen tagbuf)
      tagbuf)

    (define/public (close)
      (when ctx
        (EVP_CIPHER_CTX_free ctx)
        (set! state 4)
        (set! ctx #f)))

    (define/private (maxlen inlen)
      (+ inlen (send impl get-block-size)))
    ))