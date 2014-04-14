#lang racket/base
(provide (all-defined-out))

;; 256 bit keys

(define rsa1-priv/RSAPrivateKey
  #"0\201\253\2\1\0\2!\0\323\0\267\332\326{\354\310\233\372\224W\24\231\254\177i\334\257\231 *\317K\a\3406<\243\317\244\313\2\3\1\0\1\2!\0\302NT\0\273)\r\250\3032\242\355\371\363v\v\207\20\312\232\327\357\er\37\243[\375X\313\22I\2\21\0\354\324\202K6h\254\205\257~\367\351\332\30\342O\2\21\0\344\25\6\345[\220-\214f\372om\245\365\"\305\2\20Km\257\205\326\361e\251:h\334\372\315,\311\277\2\20\32f\234\257\273\323\212\222/\361Y(\226\a4\t\2\21\0\354\247!\262\327>\34\350\334\330\303c\317\252\22\330")

(define rsa1-pub
  #"0<0\r\6\t*\206H\206\367\r\1\1\1\5\0\3+\0000(\2!\0\323\0\267\332\326{\354\310\233\372\224W\24\231\254\177i\334\257\231 *\317K\a\3406<\243\317\244\313\2\3\1\0\1")

;; ----

(define dsa1-params
  #"0\201\234\2A\0\336P\23\22O\256\354\252\315<J\n\300\343\307\264\342\306\355\270\322\277\350~\16\226\31.\2/z\223\251HH=\264\276\244/\353'W\3@\345\325\220q\246u\323\200\335?\324\355\3159\267l\361\226-\2\25\0\270\267b\253I\351\300\272\311\5\317\334\325\304\327\216jHs7\2@P\21\343\nc\264\6;\343\2?/\235\276\342\333\346y\25\20\227\220\2032\"\5G\22\264\365T\364GxSM\250M1\4\311Ul\356\17\333@\270c\t\367f\341\2041R\237^\264y\347\337-\252")

(define dsa1-priv
  #"0\201\306\2\1\0000\201\250\6\a*\206H\3168\4\0010\201\234\2A\0\336P\23\22O\256\354\252\315<J\n\300\343\307\264\342\306\355\270\322\277\350~\16\226\31.\2/z\223\251HH=\264\276\244/\353'W\3@\345\325\220q\246u\323\200\335?\324\355\3159\267l\361\226-\2\25\0\270\267b\253I\351\300\272\311\5\317\334\325\304\327\216jHs7\2@P\21\343\nc\264\6;\343\2?/\235\276\342\333\346y\25\20\227\220\2032\"\5G\22\264\365T\364GxSM\250M1\4\311Ul\356\17\333@\270c\t\367f\341\2041R\237^\264y\347\337-\252\4\26\2\24Qe,i\243\231.\340?\34Q*\333\364\336)\363}j\257")

(define dsa1-priv/DSAPrivateKey
  #"0\201\367\2\1\0\2A\0\336P\23\22O\256\354\252\315<J\n\300\343\307\264\342\306\355\270\322\277\350~\16\226\31.\2/z\223\251HH=\264\276\244/\353'W\3@\345\325\220q\246u\323\200\335?\324\355\3159\267l\361\226-\2\25\0\270\267b\253I\351\300\272\311\5\317\334\325\304\327\216jHs7\2@P\21\343\nc\264\6;\343\2?/\235\276\342\333\346y\25\20\227\220\2032\"\5G\22\264\365T\364GxSM\250M1\4\311Ul\356\17\333@\270c\t\367f\341\2041R\237^\264y\347\337-\252\2@\2f\336v\230+\273\367M\334\27\206\256Y\260;\317\227/A\320@n\331\e\316\241\370\266W\341'+\206\302L\333'\335\201\231!\322\242\334\24\344\250r\257@=q\246\247\244\\\20\vf\315\300/\363\2\24Qe,i\243\231.\340?\34Q*\333\364\336)\363}j\257")

(define dsa1-pub
  #"0\201\3600\201\250\6\a*\206H\3168\4\0010\201\234\2A\0\336P\23\22O\256\354\252\315<J\n\300\343\307\264\342\306\355\270\322\277\350~\16\226\31.\2/z\223\251HH=\264\276\244/\353'W\3@\345\325\220q\246u\323\200\335?\324\355\3159\267l\361\226-\2\25\0\270\267b\253I\351\300\272\311\5\317\334\325\304\327\216jHs7\2@P\21\343\nc\264\6;\343\2?/\235\276\342\333\346y\25\20\227\220\2032\"\5G\22\264\365T\364GxSM\250M1\4\311Ul\356\17\333@\270c\t\367f\341\2041R\237^\264y\347\337-\252\3C\0\2@\2f\336v\230+\273\367M\334\27\206\256Y\260;\317\227/A\320@n\331\e\316\241\370\266W\341'+\206\302L\333'\335\201\231!\322\242\334\24\344\250r\257@=q\246\247\244\\\20\vf\315\300/\363")

;; ----

(define dh1-params
  '(dh
    parameters
    pkcs3
    #"0&\2!\0\232wx\363\252Z\243\365o \364\263>mw\21T3Z2\336au1\352\1774W\211^4k\2\1\2"))

(define dh1-priv
  '(dh
    private
    libcrypto
    #"0&\2!\0\232wx\363\252Z\243\365o \364\263>mw\21T3Z2\336au1\352\1774W\211^4k\2\1\2"
    #"\211\275\361W#\35y\334\fB\f\371\246H\351\35\2661)&|\357\230Y\202\21uM\363\214\247Y"
    #"@+\273\r\251\324\17a\32\3706Q@\310\5T\20|IZVy\27\375.&\351\305y\225-M"))

(define dh1-pub
  '(dh
    public
    pkix
    #"0[03\6\t*\206H\206\367\r\1\3\0010&\2!\0\232wx\363\252Z\243\365o \364\263>mw\21T3Z2\336au1\352\1774W\211^4k\2\1\2\3$\0\2!\0\211\275\361W#\35y\334\fB\f\371\246H\351\35\2661)&|\357\230Y\202\21uM\363\214\247Y"))

;; ----

;; using '((curve "NIST P-256"))

(define ec1-params
  #"0\201\367\2\1\0010,\6\a*\206H\316=\1\1\2!\0\377\377\377\377\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\377\377\377\377\377\377\377\377\377\377\377\3770[\4 \377\377\377\377\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\377\377\377\377\377\377\377\377\377\377\377\374\4 Z\3065\330\252:\223\347\263\353\275Uv\230\206\274e\35\6\260\314S\260\366;\316<>'\322`K\3\25\0\304\2356\b\206\347\4\223jfx\341\23\235&\267\201\237~\220\4A\4k\27\321\362\341,BG\370\274\346\345c\244@\362w\3}\201-\3533\240\364\2419E\330\230\302\226O\343B\342\376\32\177\233\216\347\353J|\17\236\26+\3163Wk1^\316\313\266@h7\277Q\365\2!\0\377\377\377\377\0\0\0\0\377\377\377\377\377\377\377\377\274\346\372\255\247\27\236\204\363\271\312\302\374c%Q\2\1\1")

(define ec1-priv/SEC1
  #"0\202\1h\2\1\1\4 G\327{\217\320\244\f\343(\207\314\334o~\334\277+\227\270\263\200\245E\271\363\353\2338\203i\237K\240\201\3720\201\367\2\1\0010,\6\a*\206H\316=\1\1\2!\0\377\377\377\377\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\377\377\377\377\377\377\377\377\377\377\377\3770[\4 \377\377\377\377\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\377\377\377\377\377\377\377\377\377\377\377\374\4 Z\3065\330\252:\223\347\263\353\275Uv\230\206\274e\35\6\260\314S\260\366;\316<>'\322`K\3\25\0\304\2356\b\206\347\4\223jfx\341\23\235&\267\201\237~\220\4A\4k\27\321\362\341,BG\370\274\346\345c\244@\362w\3}\201-\3533\240\364\2419E\330\230\302\226O\343B\342\376\32\177\233\216\347\353J|\17\236\26+\3163Wk1^\316\313\266@h7\277Q\365\2!\0\377\377\377\377\0\0\0\0\377\377\377\377\377\377\377\377\274\346\372\255\247\27\236\204\363\271\312\302\374c%Q\2\1\1\241D\3B\0\4|\235\312f\360%\232\202^\222t\234\214[\"XH\266M\31\302\302\223@+\263\326bKK\24RA\357^L\370\366\306\344\324Z\t\274\fx\372\31\177\2008_)#\346s*\226\4\256\210\a@\305")

(define ec1-pub
  #"0\202\1K0\202\1\3\6\a*\206H\316=\2\0010\201\367\2\1\0010,\6\a*\206H\316=\1\1\2!\0\377\377\377\377\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\377\377\377\377\377\377\377\377\377\377\377\3770[\4 \377\377\377\377\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\377\377\377\377\377\377\377\377\377\377\377\374\4 Z\3065\330\252:\223\347\263\353\275Uv\230\206\274e\35\6\260\314S\260\366;\316<>'\322`K\3\25\0\304\2356\b\206\347\4\223jfx\341\23\235&\267\201\237~\220\4A\4k\27\321\362\341,BG\370\274\346\345c\244@\362w\3}\201-\3533\240\364\2419E\330\230\302\226O\343B\342\376\32\177\233\216\347\353J|\17\236\26+\3163Wk1^\316\313\266@h7\277Q\365\2!\0\377\377\377\377\0\0\0\0\377\377\377\377\377\377\377\377\274\346\372\255\247\27\236\204\363\271\312\302\374c%Q\2\1\1\3B\0\4|\235\312f\360%\232\202^\222t\234\214[\"XH\266M\31\302\302\223@+\263\326bKK\24RA\357^L\370\366\306\344\324Z\t\274\fx\372\31\177\2008_)#\346s*\226\4\256\210\a@\305")

;; Also using NIST P-256, but with parameters as named curve

(define ec2-params
  #"\6\b*\206H\316=\3\1\a")

(define ec2-priv
  #"0\201\207\2\1\0000\23\6\a*\206H\316=\2\1\6\b*\206H\316=\3\1\a\4m0k\2\1\1\4 'L*\303\26\307\352\48\242Xy+\361\5\320K<\363x\317\371:\303G\254\300E\241a\5\200\241D\3B\0\4\223\260v+\221#\17\36\340,\3704\322\213g/gY\224\371(\260Z\200\3231\210\t\\\337X|\n\305\243\274\4g\225\346\0NQ\206D\262\236-\237o\4\205[>6H\243\352\30\335\240ys\336")

(define ec2-priv/SEC1
  #"0w\2\1\1\4 'L*\303\26\307\352\48\242Xy+\361\5\320K<\363x\317\371:\303G\254\300E\241a\5\200\240\n\6\b*\206H\316=\3\1\a\241D\3B\0\4\223\260v+\221#\17\36\340,\3704\322\213g/gY\224\371(\260Z\200\3231\210\t\\\337X|\n\305\243\274\4g\225\346\0NQ\206D\262\236-\237o\4\205[>6H\243\352\30\335\240ys\336")

(define ec2-pub
  #"0Y0\23\6\a*\206H\316=\2\1\6\b*\206H\316=\3\1\a\3B\0\4\223\260v+\221#\17\36\340,\3704\322\213g/gY\224\371(\260Z\200\3231\210\t\\\337X|\n\305\243\274\4g\225\346\0NQ\206D\262\236-\237o\4\205[>6H\243\352\30\335\240ys\336")

;; ============================================================

;; 2048-bit keys

(define dsa2-params
  #"0\202\29\6\a*\206H\3168\4\0010\202\2,\2\202\1\1\0\272fB E)\242&\227\230\4\f\243\217\2\373LnA\375\373\365$\30\335l\377\316\320VC0b)\240\340\350\205\215\237\207\375\334t\353\"HK&\265\255/'\214\330\4]zM\"3\354\326J\341%\b\fp\367\332\36<d\262@#\246\314\336n\210C\361e\364\22\273\354\230n\364gU\325\300I\363\1\267q\205>H\r\302$\200\376Lo\264\355\276\216;\326M\276Q'n\241a\222$\226^\247\254\367BZ\22%\21\303M\35\270\345\204\v\24\fB\\J\242L\271\204-o\325.J\23{L\247\230m\376n\236\3710\335\262\n\t\214Z\261!\326\24\333\320|R\225\351\316o\221\376T\17 c\371\265<G\273RX\31\363K\221J\320\242\247\220\354e\267\274\0042\330\233J-@\250pG<.[\315\342\222\332\240\231P\270\260\230'\367\223\35|\37}\177\303\223vq\a\350\235g\247\304\253\35\345\2!\0\213\35\220\6Nm\354\3131\355\337\257\342S\251QX,\3409c\336I\255Q\375\353pj\220v\361\2\202\1\0\24\322C1%%\271\204\fq\210d\313\a@\n \354\3058~\267\350\22~k4\n\217i5\231\b\235y\272\240Xf\6\201\265\34CwA\231\234\231\214\272\224\273o\374\240\254\370|\2\260\343\210\237\234\212B6\341\336\312\345\351\247\351WeM\300\245\260* \34n\221\"\244\344\334\4PEdcv3\255s\21I\340\316/j\266xG\245\5>??\22\362\27\201\355>'\220Eb\271\302\20YaeK\4\322G\32A\aR2\25\206\350\342m\325[\266\264\325\221\302\nP\207\256\21\3\235^\322\27\341\315\201'\216\237V\262\354\373\347\311v\233}\247$Th\253b\1\375_+\274\341\177}\325\265\325\313\256\324\3@\205\f\321\217s\343\300d\374\377v\207\247\235\251\336\341\342\357\301C\230$N\250\357\20\344\317\200\"\356c\370\22v\211\361\1\242\e\207@\355$\37\275P\355\353\271\331\337~X\21\222(4")

(define dsa2-priv
  #"0\202\2e\2\1\0000\202\29\6\a*\206H\3168\4\0010\202\2,\2\202\1\1\0\272fB E)\242&\227\230\4\f\243\217\2\373LnA\375\373\365$\30\335l\377\316\320VC0b)\240\340\350\205\215\237\207\375\334t\353\"HK&\265\255/'\214\330\4]zM\"3\354\326J\341%\b\fp\367\332\36<d\262@#\246\314\336n\210C\361e\364\22\273\354\230n\364gU\325\300I\363\1\267q\205>H\r\302$\200\376Lo\264\355\276\216;\326M\276Q'n\241a\222$\226^\247\254\367BZ\22%\21\303M\35\270\345\204\v\24\fB\\J\242L\271\204-o\325.J\23{L\247\230m\376n\236\3710\335\262\n\t\214Z\261!\326\24\333\320|R\225\351\316o\221\376T\17 c\371\265<G\273RX\31\363K\221J\320\242\247\220\354e\267\274\0042\330\233J-@\250pG<.[\315\342\222\332\240\231P\270\260\230'\367\223\35|\37}\177\303\223vq\a\350\235g\247\304\253\35\345\2!\0\213\35\220\6Nm\354\3131\355\337\257\342S\251QX,\3409c\336I\255Q\375\353pj\220v\361\2\202\1\0\24\322C1%%\271\204\fq\210d\313\a@\n \354\3058~\267\350\22~k4\n\217i5\231\b\235y\272\240Xf\6\201\265\34CwA\231\234\231\214\272\224\273o\374\240\254\370|\2\260\343\210\237\234\212B6\341\336\312\345\351\247\351WeM\300\245\260* \34n\221\"\244\344\334\4PEdcv3\255s\21I\340\316/j\266xG\245\5>??\22\362\27\201\355>'\220Eb\271\302\20YaeK\4\322G\32A\aR2\25\206\350\342m\325[\266\264\325\221\302\nP\207\256\21\3\235^\322\27\341\315\201'\216\237V\262\354\373\347\311v\233}\247$Th\253b\1\375_+\274\341\177}\325\265\325\313\256\324\3@\205\f\321\217s\343\300d\374\377v\207\247\235\251\336\341\342\357\301C\230$N\250\357\20\344\317\200\"\356c\370\22v\211\361\1\242\e\207@\355$\37\275P\355\353\271\331\337~X\21\222(4\4#\2!\0\204\345\343\365\264z\354VZ!J\345\25D\222\271\4\367\364.\263|\341\271N\372\311\"\277\f.\322")