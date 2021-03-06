;; Copyright 2012-2018 Ryan Culpepper
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
(require racket/class
         racket/dict
         rackunit
         crypto
         crypto/private/common/interfaces
         crypto/private/common/catalog
         "util.rkt")
(provide test-digests
         test-digests-agree
         digest-inputs)

(define (test-digests factory)
  (for ([name (sort (hash-keys known-digests) symbol<?)])
    (let ([di (send factory get-digest name)])
      (when di
        (test-case (format "~s" name)
          (when #t (hprintf 1 "testing ~v\n" name))
          (test-digest-meta di)
          (for ([in+out (dict-ref digest-test-vectors name null)])
            (test-digest/in+out di (car in+out) (hex->bytes (cadr in+out)) #f))
          (for ([in digest-inputs])
            (test-digest/solo di in)))))))

(define (test-digest-meta di)
  (for ([di (list di (send di get-spec))])
    (digest-size di)
    (digest-block-size di)))

(define (test-digest/solo di in)
  ;; All-at-once digest agrees with incremental
  (define md (digest di in))
  (check-equal? (digest di (open-input-bytes in)) md)
  (let ([dctx (make-digest-ctx di)])
    (for ([inb (in-bytes in)])
      (digest-update dctx (bytes inb)))
    (cond [(digest-peek-final dctx)
           => (lambda (md*) (check-equal? md* md))])
    (check-equal? (digest-final dctx) md))
  (let ()
    (define r 57)
    (define inlen (bytes-length in))
    (define in* (bytes-append (make-bytes r 65) in (make-bytes r 66)))
    (check-equal? (digest di (bytes-range in* r (+ r inlen))) md)
    (let ([dctx (make-digest-ctx di)])
      (digest-update dctx (bytes-range in* r (+ r inlen)))
      (check-equal? (digest-final dctx) md))
    (let ([dctx (make-digest-ctx di)])
      (for ([i (in-range inlen)])
        (digest-update dctx (bytes-range in* (+ r i) (+ r i 1))))
      (check-equal? (digest-final dctx) md)))
  ;; Check keyed digest, if supported
  (for ([keylen '(16)]
        #:when (send di key-size-ok? keylen))
    (define key (semirandom-bytes keylen))
    (define kmd (digest di in #:key key))
    (check-equal? (digest di (open-input-bytes in) #:key key) kmd)
    (let ([kctx (make-digest-ctx di #:key key)])
      (digest-update kctx in)
      (check-equal? (digest-final kctx) kmd)))
  ;; All-at-once HMAC agrees with incremental
  (for ([key digest-keys])
    (define h (hmac di key in))
    (let ([hctx (make-hmac-ctx di key)])
      (for ([inb (in-bytes in)])
        (digest-update hctx (bytes inb)))
      (cond [(digest-peek-final hctx)
             => (lambda (h*) (check-equal? h* h))])
      (check-equal? (digest-final hctx) h))))

;; ----

(define (test-digests-agree factories)
  (for ([name (sort (hash-keys known-digests) symbol<?)])
    (let ([impls
           (filter values
                   (for/list ([factory factories])
                     (send factory get-digest name)))])
      (when (zero? (length impls))
        (hprintf -1 "no impl for digest ~e\n" name))
      (when (= (length impls) 1)
        (hprintf -1 "only one impl for digest ~e (~s)\n" name
                 (send (send (car impls) get-factory) get-name)))
      (when (> (length impls) 1)
        (when #t
          (hprintf 1 "testing agreement ~e\n" name))
        (define impl0 (car impls))
        (for ([impl (cdr impls)])
          (for ([in digest-inputs])
            (test-digest-impls-agree impl impl0 in))
          (for* ([key digest-keys]
                 [in digest-inputs])
            (test-hmac-impls-agree impl impl0 key in)))))))

(define (test-digest-impls-agree di di-base in)
  (test-digest/in+out di in (digest di-base in) #f)
  (for ([keylen '(16)])
    (when (and (send di key-size-ok? keylen) (send di-base key-size-ok? keylen))
      (define key (semirandom-bytes keylen))
      (test-digest/in+out di in (digest di-base in #:key key) key))))

(define (test-digest/in+out di in out key)
  (test-case (format "~a: ~e" (send di get-spec) in)
    (check-equal? (digest di in #:key key) out)
    (check-equal? (digest di (open-input-bytes in) #:key key) out)
    (let ([ctx (make-digest-ctx di #:key key)])
      (digest-update ctx in)
      (check-equal? (digest-peek-final ctx) out)
      (check-equal? (digest-final ctx) out))))

(define (test-hmac-impls-agree di di-base key in)
  (test-hmac/in+out di key in (hmac di-base key in)))

(define (test-hmac/in+out di key in out)
  (test-case (format "HMAC ~a: ~e" (send di get-spec) in)
    (check-equal? (hmac di key in) out)
    (check-equal? (hmac di key (open-input-bytes in)) out)
    (let ([ctx (make-hmac-ctx di key)])
      (digest-update ctx in)
      (check-equal? (digest-final ctx) out))
    (let* ([r 57]
           [in* (bytes-append (make-bytes r 65) in (make-bytes r 66))])
      (let ([ctx (make-hmac-ctx di key)])
        (digest-update ctx (bytes-range in* r (+ r (bytes-length in))))
        (check-equal? (digest-final ctx) out))
      (let ([ctx (make-hmac-ctx di key)])
        (for ([i (in-range r (+ r (bytes-length in)))])
          (digest-update ctx (bytes-range in* i (add1 i))))
        (check-equal? (digest-final ctx) out)))))

;; ----------------------------------------

(define digest-test-vectors
  '([md5
     (#""
      #"d41d8cd98f00b204e9800998ecf8427e")
     (#"abc"
      #"900150983cd24fb0d6963f7d28e17f72")
     (#"abcdef"
      #"e80b5017098950fc58aad83c8c14978e")]
    [sha1
     (#""
      #"da39a3ee5e6b4b0d3255bfef95601890afd80709")
     (#"abc"
      #"a9993e364706816aba3e25717850c26c9cd0d89d")
     (#"abcdef"
      #"1f8ac10f23c5b5bc1167bda84b833e5c057a77d2")]
    [sha256
     (#""
      #"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
     (#"abc"
      #"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
     (#"abcdef"
      #"bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721")]))

(define digest-inputs
  `(#""
    #"abc"
    #"abcdef"
    #"The cat is in the box."
    ,(semirandom-bytes 10)
    ,(semirandom-bytes 100)
    ,(semirandom-bytes 1024)
    ,(semirandom-bytes 10000)))

(define digest-keys
  `(#"secret!"
    ,(semirandom-bytes/alpha 10)
    ,(semirandom-bytes/alpha 20)
    ,(semirandom-bytes/alpha 40)))
