;; Copyright 2012 Ryan Culpepper
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
(require racket/class
         racket/system
         racket/string
         racket/port
         racket/file
         "../common/interfaces.rkt"
         "../common/common.rkt"
         (only-in "../ssl/util.rkt" hex unhex))
(provide (all-defined-out))

;; random-bytes-no-nuls : nat -> bytes-no-nuls
(define (random-bytes-no-nuls size)
  (let ([bs (make-bytes size)])
    (for ([i (in-range size)])
      (bytes-set! bs i (add1 (random 254))))
    bs))

;; ============================================================

(define process-handler%
  (class base-ctx%
    (super-new)

    (field [sp #f]
           [spout #f]
           [spin #f]
           [sperr #f])

    (define args
      (for/list ([arg (get-openssl-args)] #:when arg)
        (format "~a" arg)))

    (set!-values (sp spout spin sperr)
      (apply subprocess #f #f #f "/usr/bin/openssl" args))

    (eprintf "** ~a\n" (string-join (cons "/usr/bin/openssl" args) " "))

    (abstract get-openssl-args)

    (define/public (write! who buf start end)
      (write-bytes buf spin start end)
      (flush-output spin)
      (void))

    (define/public (close/read who)
      (close-output-port spin)
      (sync sp)
      (let ([err (port->string sperr)])
        (unless (zero? (string-length err))
          (eprintf "~a\n" err)))
      (close-input-port sperr)
      (begin0 (port->bytes spout)
        (close-input-port spout)))
    ))

(define process/args%
  (class process-handler%
    (init-field args)
    (super-new)
    (define/override (get-openssl-args) args)))

(define (openssl #:in [send-to-in #f] . args)
  (let ([p (new process/args% (impl #f) (args args))])
    (when send-to-in
      (send p write! 'openssl send-to-in 0 (bytes-length send-to-in)))
    (send p close/read 'openssl)))

(define-syntax-rule (with-tmp-files ([id contents] ...) . body)
  (let ([id (make-temporary-file)] ...)
    (with-output-to-file id #:exists 'truncate (lambda () (write-bytes contents))) ...
    (call-with-continuation-barrier
     (lambda ()
       (dynamic-wind void
                     (lambda () . body)
                     (lambda () (delete-file id) ... (void)))))))

;; ============================================================

(define digest-impl%
  (class* object% (digest-impl<%>)
    (init-field name
                size
                block-size)
    (super-new)

    (define/public (get-name) name)
    (define/public (get-size) size)
    (define/public (get-block-size) block-size)

    (define/public (new-ctx)
      (new digest-ctx% (impl this)))
    (define/public (get-hmac-impl who)
      (new hmac-impl% (digest this)))
    (define/public (hmac-buffer who key buf start end) #f)
    (define/public (generate-hmac-key)
      (random-bytes-no-nuls size))
    ))

(define hmac-impl%
  (class* object% (hmac-impl<%>)
    (init-field digest)
    (super-new)

    (define/public (get-digest) digest)
    (define/public (new-ctx who key)
      ;; There seems to be no way to pass HMAC keys containing embedded NUL bytes :(
      (unless (bytes-no-nuls? key)
        (error who "key must not contain NUL byte, got: ~e" key))
      (new digest-ctx% (impl digest) (hmac-key key)))
    ))

(define digest-ctx%
  (class* base-ctx% (digest-ctx<%>)
    (init-field [hmac-key #f])
    (inherit-field impl)
    (super-new)

    (define stored-content (open-output-bytes))

    (define/public (get-content who reset?)
      (begin0 (get-output-bytes stored-content)
        (when reset? (set! stored-content #f))))

    (define/public (update! who buf start end)
      (void (write-bytes buf stored-content start end)))

    (define/public (final! who buf start end)
      (let* ([content (get-content who #t)]
             [md (openssl "dgst" (format "-a~a" (send impl get-name)) "-binary"
                          (and hmac-key "-hmac") hmac-key
                          #:in content)])
        (bytes-copy! buf start md)
        (bytes-length md)))

    (define/public (copy who)
      (let* ([content-so-far (get-content who #f)]
             [dg2 (new digest-ctx% (impl impl) (hmac-key hmac-key))])
        (send dg2 update! who content-so-far 0 (bytes-length content-so-far))
        dg2))
    ))

(define (di name size block-size)
  (new digest-impl% (name name) (size size) (block-size block-size)))

(define digest:md5 (di "md5" 16 64))
(define digest:ripemd160 (di "rmd160" 20 64))
(define digest:dss1 (di "dss1" 20 64))
(define digest:sha1 (di "sha1" 20 64))
(define digest:sha224 (di "sha224" 28 64))
(define digest:sha256 (di "sha256" 32 64))
(define digest:sha384 (di "sha384" 48 128))
(define digest:sha512 (di "sha512" 64 128))

;; ============================================================

(define cipher-impl%
  (class* object% (cipher-impl<%>)
    (init-field name keylen blocklen [ivlen blocklen])
    (super-new)

    (define/public (get-name) name)
    (define/public (get-key-size) keylen)
    (define/public (get-block-size) blocklen)
    (define/public (get-iv-size) ivlen)

    (define/public (new-ctx who key iv enc? pad?)
      (new cipher-ctx% (impl this) (key key) (iv iv) (enc? enc?) (pad? pad?)))

    (define/public (generate-key+iv)
      (values (random-bytes-no-nuls keylen)
              (and ivlen (random-bytes-no-nuls ivlen))))
    ))

(define cipher-ctx%
  (class* process-handler% (cipher-ctx<%>)
    (init-field key iv enc? pad?)
    (inherit-field impl spout)
    (inherit write! close/read)
    (super-new)

    (define/override (get-openssl-args)
      (list* "enc"
             (format "-~a" (send impl get-name))
             (if enc? "-e" "-d")
             "-bufsize" "1"
             "-K" (bytes->string/latin-1 (hex key))
             (append (if pad? '() '("-nopad"))
                     (if iv (list "-iv" (bytes->string/latin-1 (hex iv))) '()))))

    #|
    The openssl enc command doesn't write *any* data until it's been sent
    everything. (Or so it seems... need to investigate -bufsize more.)
    So the normal update! interface doesn't work at all... it just happens to
    work currently on short data because the implementation of final! below
    doesn't respect the end arg and cipher-pump uses larger buffers.

    This probably the current update!/final! interface is bad and should be
    replaced. Perhaps update!/final! should allocate bytes; perhaps should
    take an output port arg. Or allow some implementation choice.
    |#

    (define/public (update! who inbuf instart inend outbuf outstart outend)
      (write! who inbuf instart inend)
      (let ([n (read-bytes-avail!* outbuf spout outstart outend)])
        n))

    (define/public (final! who buf start end)
      (let ([tail (close/read who)])
        (bytes-copy! buf start tail)
        (bytes-length tail)))
    ))

(define (ci name keylen blocklen ivlen)
  (new cipher-impl% (name name) (keylen keylen) (blocklen blocklen) (ivlen ivlen)))

(define cipher:aes-128-cbc (ci "aes-128-cbc" 16 16 16))
(define cipher:aes-128-ecb (ci "aes-128-ecb" 16 16 #f))
(define cipher:aes-128     cipher:aes-128-cbc)

(define cipher:aes-192-cbc (ci "aes-192-cbc" 24 16 16))
(define cipher:aes-192-ecb (ci "aes-192-ecb" 24 16 #f))
(define cipher:aes-192     cipher:aes-192-cbc)

(define cipher:aes-256-cbc (ci "aes-256-cbc" 32 16 16))
(define cipher:aes-256-ecb (ci "aes-256-ecb" 32 16 #f))
(define cipher:aes-256     cipher:aes-256-cbc)

;; ============================================================

#|
*** Don't ever use this code with sensitive keys. ***

Since most openssl commands take keys as filenames, we write keys to temp files.

{read,write}-key uses PEM format instead of DER
FIXME: check again whether DER available in older versions
|#

(define pkey-impl%
  (class* object% (pkey-impl<%>)
    (init-field sys)
    (super-new)

    (define/public (read-key who public? buf start end)
      (let ([key (subbytes buf start end)])
        (new pkey-ctx% (impl this) (key key) (private? (not public?)))))

    (define/public (generate-key args)
      (let* ([key
              (case sys
                ((rsa) (openssl "genrsa" (car args)))
                ((dsa) (openssl "gendsa" (car args))))])
        (new pkey-ctx% (impl this) (key key) (private? #t))))

    (define/public (digest-ok? di)
      (case sys
        ((rsa)
         (and (member di (list digest:ripemd160 digest:sha1 digest:sha224
                               digest:sha256 digest:sha384 digest:sha512))
              #t))
        ((dsa)
         (and (member di (list digest:dss1)) #t))))
    ))

(define pkey-ctx%
  (class* base-ctx% (pkey-ctx<%>)
    (init-field key private?)
    (inherit-field impl)
    (super-new)

    (define/public (is-private?) private?)
    (define/public (get-max-signature-size) 10000) ;; FIXME
    (define/public (get-key-size/bits)
      (error 'get-key-size/bits "not implemented"))

    (define/public (write-key who want-public?)
      (let ([want-private? (not want-public?)])
        (cond [(and private? want-private?) key]
              [(and private? (not want-private?))
               (openssl (send impl get-name) "-pubout" #:in key)]
              [(and (not private?) want-private?)
               (error who "only public key component is available")]
              [(and (not private?) (not want-private?)) key])))

    (define/public (equal-to-key? pkctx)
      (equal? key (get-field key pkctx)))

    #|
    Cannot sign an existing digest-context using command line, so we make
    digest store all data.

    Again, suggests a more flexible interface might be good.
    |#

    (define/public (sign! who dg buf start end)
      (unless private?
        (error who "cannot sign with public key"))
      (with-tmp-files ([keyfile key])
        (let* ([impl (send dg get-impl)]
               [signature
                (openssl "dgst" (format "-~a" (send impl get-name)) "-binary"
                         "-sign" keyfile
                         #:in (send dg get-content who #f))])
          (bytes-copy! buf start signature)
          (bytes-length signature))))

    (define/public (verify who dg buf start end)
      (with-tmp-files ([keyfile key]
                       [sigfile (subbytes buf start end)])
        (let* ([impl (send dg get-impl)]
               [result
                (openssl "dgst" (format "-~a" (send impl get-name))
                         (if private? "-prverify" "-verify") keyfile
                         "-signature" sigfile
                         #:in (send dg get-content who #f))])
          (cond [(regexp-match? #rx#"OK" result)
                 #t]
                [(regexp-match #rx#"Fail" result)
                 #f]
                [else
                 (error who "internal error; openssl returned unexpected result: ~e"
                        result)]))))

    (define/public (encrypt/decrypt who encrypt? want-public? inbuf instart inend)
      (case (get-field sys impl)
        ((dsa)
         (error who "operation not supported for DSA"))
        ((rsa)
         (unless (or want-public? private?)
           (error who "not a private key"))
         (with-tmp-files ([keyfile key])
           (let ([result
                  (openssl "rsautl"
                           "-inkey" keyfile
                          (and want-public? "-pubin")
                           (if encrypt? "-encrypt" "-decrypt")
                           #:in (subbytes inbuf instart inend))])
             result)))))
    ))

(define pkey:rsa (new pkey-impl% (sys 'rsa)))
(define pkey:dsa (new pkey-impl% (sys 'dsa)))

;; ============================================================

(require "../common/digest.rkt"
         "../common/cipher.rkt"
         "../common/pkey.rkt")
(provide (all-from-out "../common/digest.rkt")
         (all-from-out "../common/cipher.rkt")
         (all-from-out "../common/pkey.rkt"))

(define key16 #"keyAkeyBkeyCkeyD")
(define key00 #"keyAkey\0keyCkeyD")
(define iv16  #"ivIVivIVivIVivIV")
(define data  #"hello goodbye")