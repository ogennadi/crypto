#lang scribble/doc
@(require scribble/manual
          scribble/basic
          (for-label racket/base
                     racket/contract
                     crypto
                     crypto/libcrypto
                     crypto/nettle
                     crypto/gcrypt))

@title[#:tag "factory"]{Cryptography Providers}

This library relies on foreign libraries for the implementations of
cryptographic primitives. Each foreign library is called a
@emph{cryptography provider} and it has an associated @emph{factory}
that map cryptographic @emph{algorithm specifiers} to
@emph{implementations}. A cryptography provider may also export other
functions---for example, to initialize a random number generator.

Cryptography providers may be used to obtain algorithm implementations
either explicitly or implicitly. An implementation of a cryptographic
algorithm may be obtained @emph{explicitly} by calling the appropriate
function (eg, @racket[get-digest], @racket[get-cipher], etc) on a
factory or list of factories. Alternatively, most functions provided
by this library for performing cryptographic operations accept either
a implementation object or an algorithm specifier. If an algorithm
specifier is given, an implementation is @emph{implicitly} sought from
the factories in @racket[(crypto-factories)]; if no implementation is
available, an exception is raised.

@defproc[(crypto-factory? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a crypto factory, @racket[#f]
otherwise.
}

@defparam[crypto-factories factories (listof crypto-factory?)]{

The list of crypto factories used when implicitly finding an
implementation of a cryptographic algorithm from an algorithm
specifier.

The initial value is @racket['()].
}

@defproc[(get-factory [i (or/c digest-impl? digest-ctx?
                               cipher-impl? cipher-ctx?
                               pk-impl? pk-parameters? pk-key?
                               random-impl?)])
         crypto-factory?]{

Gets the factory associated with a particular cryptographic algorithm
implementation.
}

@;{----------------------------------------}


@section{Libcrypto (OpenSSL)}

@defmodule[crypto/libcrypto]

@defthing[libcrypto-factory crypto-factory?]{

Factory for
@hyperlink["http://www.openssl.org/docs/crypto/crypto.html"]{libcrypto},
the cryptography library of OpenSSL. The necessary foreign library is
typically part of the operating system or distributed with Racket.

@bold{CSPRNG Initialization} The libcrypto library automatically seeds
its CSPRNG using entropy obtained from the operating system
(@hyperlink["http://wiki.openssl.org/index.php/Random_Numbers"]{as
described here}).
}

@section{GCrypt}

@defmodule[crypto/gcrypt]

@defthing[gcrypt-factory crypto-factory?]{

Factory for
@hyperlink["http://www.gnu.org/software/libgcrypt/"]{GCrypt}, a
cryptography library from the GNU project, originally part of GnuPG.
The @tt{libgcrypt.so.11} foreign library is required.

@bold{CSPRNG Initialization} The libgcrypt library seems to perform
some default CSPRNG initialization, but I don't know the details.
}

@section{Nettle}

@defmodule[crypto/nettle]

@defthing[nettle-factory crypto-factory?]{

Factory for
@hyperlink["http://www.lysator.liu.se/~nisse/nettle/"]{Nettle}, a
lightweight cryptography library. The @tt{libnettle.so.4} foreign
library is required.

@bold{CSPRNG Initialization} This library creates a Yarrow-256
instance and seeds it with entropy obtained from the operating system
via @tt{/dev/urandom} on Unix-like systems or the @tt{RtlGenRandom}
system call on Windows. The instance does not automatically update its
entropy pool, so it does @bold{not} enjoy Yarrow's key-compromise
recovery properties.
}