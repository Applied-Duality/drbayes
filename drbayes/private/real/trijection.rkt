#lang typed/racket/base

(require racket/match
         racket/list
         "../set.rkt"
         "../flonum.rkt")

(provide (all-defined-out))

;; ===================================================================================================
;; Image computation for uniformly strictly monotone R x R -> R functions

(: strictly-monotone2d-image (-> Boolean Boolean
                                 (-> Flonum Flonum Flonum)
                                 (-> Flonum Flonum Flonum)
                                 Set Set
                                 Set))
(define (strictly-monotone2d-image inc1? inc2? f/rndd f/rndu A B)
  (bot-basic
   (real-set-map
    (λ (A)
      (let-values ([(a1 a2 a1? a2?)  (let-values ([(a1 a2 a1? a2?)  (interval-fields A)])
                                       (cond [inc1?  (values a1 a2 a1? a2?)]
                                             [else   (values a2 a1 a2? a1?)]))])
        (real-set-map
         (λ (B)
           (let-values ([(b1 b2 b1? b2?)  (let-values ([(b1 b2 b1? b2?)  (interval-fields B)])
                                            (cond [inc2?  (values b1 b2 b1? b2?)]
                                                  [else   (values b2 b1 b2? b1?)]))])
             (interval (f/rndd a1 b1) (f/rndu a2 b2) (and a1? b1?) (and a2? b2?))))
         (set-take-reals B))))
    (set-take-reals A))))

;; ===================================================================================================
;; Trijections (axis-invertible functions and their axial inverses)

(struct: trijection ([inc1? : Boolean]
                     [inc2? : Boolean]
                     [domain1 : Nonempty-Interval]
                     [domain2 : Nonempty-Interval]
                     [range : Nonempty-Interval]
                     [fc/rndd : (-> Flonum Flonum Flonum)]
                     [fc/rndu : (-> Flonum Flonum Flonum)]
                     [fa/rndd : (-> Flonum Flonum Flonum)]
                     [fa/rndu : (-> Flonum Flonum Flonum)]
                     [fb/rndd : (-> Flonum Flonum Flonum)]
                     [fb/rndu : (-> Flonum Flonum Flonum)])
  #:transparent)

(: first-inverse-directions (-> Boolean Boolean (Values Boolean Boolean)))
(define (first-inverse-directions inc1? inc2?)
  (values (not (eq? inc1? inc2?)) inc1?))

(: second-inverse-directions (-> Boolean Boolean (Values Boolean Boolean)))
(define (second-inverse-directions inc1? inc2?)
  (let-values ([(inc1? inc2?)  (first-inverse-directions inc1? inc2?)])
    (first-inverse-directions inc1? inc2?)))

(: trijection-first-inverse (-> trijection trijection))
(define (trijection-first-inverse f)
  (match-define (trijection inc1? inc2? X Y Z fc/rndd fc/rndu fa/rndd fa/rndu fb/rndd fb/rndu) f)
  (define-values (fa-inc1? fa-inc2?) (first-inverse-directions inc1? inc2?))
  (trijection fa-inc1? fa-inc2? Y Z X fa/rndd fa/rndu fb/rndd fb/rndu fc/rndd fc/rndu))

(: trijection-second-inverse (-> trijection trijection))
(define (trijection-second-inverse f)
  (trijection-first-inverse (trijection-first-inverse f)))

(: trijection-image (-> trijection (-> Set Set)))
(define (trijection-image f)
  (match-define (trijection inc1? inc2? X Y Z fc/rndd fc/rndu _ _ _ _) f)
  (λ (A×B)
    (define-values (A B) (set-projs A×B))
    (let ([A  (set-intersect A X)]
          [B  (set-intersect B Y)])
      (set-intersect (strictly-monotone2d-image inc1? inc2? fc/rndd fc/rndu A B) Z))))

(: trijection-preimage (-> trijection (-> Set (-> Set Set))))
(define (trijection-preimage f)
  (match-define (trijection fc-inc1? fc-inc2? X Y Z _ _ fa/rndd fa/rndu fb/rndd fb/rndu) f)
  (define-values (fa-inc1? fa-inc2?) (first-inverse-directions fc-inc1? fc-inc2?))
  (define-values (fb-inc1? fb-inc2?) (first-inverse-directions fa-inc1? fa-inc2?))
  (λ (A×B)
    (define-values (A B) (set-projs A×B))
    (let ([A  (set-intersect A X)]
          [B  (set-intersect B Y)])
      (λ (C)
        (let ([C  (set-intersect C Z)])
          (set-pair
           (set-intersect (strictly-monotone2d-image fa-inc1? fa-inc2? fa/rndd fa/rndu B C) A)
           (set-intersect (strictly-monotone2d-image fb-inc1? fb-inc2? fb/rndd fb/rndu C A) B)))))))

;; ===================================================================================================
;; Some trijections

(: zeros1+ (-> (-> Flonum Flonum Flonum) (-> Flonum Flonum Flonum)))
(: zeros1- (-> (-> Flonum Flonum Flonum) (-> Flonum Flonum Flonum)))
(: zeros2+ (-> (-> Flonum Flonum Flonum) (-> Flonum Flonum Flonum)))
(: zeros2- (-> (-> Flonum Flonum Flonum) (-> Flonum Flonum Flonum)))

(define ((zeros1+ f) x y) (f (if (zero? x) +0.0 x) y))
(define ((zeros1- f) x y) (f (if (zero? x) -0.0 x) y))
(define ((zeros2+ f) x y) (f x (if (zero? y) +0.0 y)))
(define ((zeros2- f) x y) (f x (if (zero? y) -0.0 y)))

#|
c = a + b    Addition
a = c - b    Reverse subtraction
b = c - a    Subtraction
|#

(define trij-add
  (trijection #t #t reals reals reals
              fl+/rndd fl+/rndu
              flrev-/rndd flrev-/rndu
              fl-/rndd fl-/rndu))

(define trij-sub (trijection-second-inverse trij-add))

#|
c = a * b    Multiplication
a = c / b    Reverse division
b = c / a    Division
|#

(define trij-mul++
  (trijection #t #t positive-interval positive-interval positive-interval
              fl*/rndd fl*/rndu
              (zeros1+ flrev//rndd) (zeros1+ flrev//rndu)
              (zeros2+ fl//rndd) (zeros2+ fl//rndu)))

(define trij-mul+-
  (trijection #f #t positive-interval negative-interval negative-interval
              fl*/rndd fl*/rndu
              (zeros1- flrev//rndd) (zeros1- flrev//rndu)
              (zeros2+ fl//rndd) (zeros2+ fl//rndu)))

(define trij-mul-+
  (trijection #t #f negative-interval positive-interval negative-interval
              fl*/rndd fl*/rndu
              (zeros1+ flrev//rndd) (zeros1+ flrev//rndu)
              (zeros2- fl//rndd) (zeros2- fl//rndu)))

(define trij-mul--
  (trijection #f #f negative-interval negative-interval positive-interval
              fl*/rndd fl*/rndu
              (zeros1- flrev//rndd) (zeros1- flrev//rndu)
              (zeros2- fl//rndd) (zeros2- fl//rndu)))

;; These inverses may unexpected - until their domains are considered
(define trij-div++ (trijection-second-inverse trij-mul++))
(define trij-div+- (trijection-second-inverse trij-mul--))
(define trij-div-+ (trijection-second-inverse trij-mul+-))
(define trij-div-- (trijection-second-inverse trij-mul-+))

#|
TODO

#|
c = a^b
a = c^(1/b)
b = log(c)/log(a)
|#

(: flexptinv1/rndd (-> Flonum Flonum Flonum))
(define (flexptinv1/rndd b c)
  (flexpt/rndd c (if (c . fl> . 1.0) (flrecip/rndd b) (flrecip/rndu b))))

(: flexptinv1/rndu (-> Flonum Flonum Flonum))
(define (flexptinv1/rndu b c)
  (flexpt/rndu c (if (c . fl> . 1.0) (flrecip/rndu b) (flrecip/rndd b))))

(: flexptinv2/rndd (-> Flonum Flonum Flonum))
(define (flexptinv2/rndd c a)
  (fl//rndd (fllog/rndd c) (fllog/rndu a)))

(: flexptinv2/rndu (-> Flonum Flonum Flonum))
(define (flexptinv2/rndu c a)
  (fl//rndu (fllog/rndu c) (fllog/rndd a)))

(define trij-expt++
  (trijection #t #t
              (Nonextremal-Interval 1.0 +inf.0 #f #f)
              positive-interval
              (Nonextremal-Interval 1.0 +inf.0 #f #f)
              flexpt/rndd flexpt/rndu
              (zeros1+ flexptinv1/rndd) (zeros1+ flexptinv1/rndu)
              flexptinv2/rndd flexptinv2/rndu))

(define trij-expt+-
  (trijection #f #t
              (Nonextremal-Interval 1.0 +inf.0 #f #f)
              negative-interval
              (Nonextremal-Interval 0.0 1.0 #f #f)
              flexpt/rndd flexpt/rndu
              flexptinv1/rndd flexptinv1/rndu
              flexptinv2/rndd flexptinv2/rndu))

(define trij-expt-+
  (trijection #t #f
              (Nonextremal-Interval 0.0 1.0 #f #f)
              positive-interval
              (Nonextremal-Interval 0.0 1.0 #f #f)
              flexpt/rndd flexpt/rndu
              (zeros2+ (zeros1+ flexptinv1/rndd)) (zeros2+ (zeros1+ flexptinv1/rndu))
              flexptinv2/rndd flexptinv2/rndu))

(define trij-expt--
  (trijection #f #f
              (Nonextremal-Interval 0.0 1.0 #f #f)
              negative-interval
              (Nonextremal-Interval 1.0 +inf.0 #f #f)
              flexpt/rndd flexpt/rndu
              flexptinv1/rndd flexptinv1/rndu
              flexptinv2/rndd flexptinv2/rndu))
|#