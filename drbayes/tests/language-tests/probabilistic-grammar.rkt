#lang typed/racket

(require plot/typed
         math/distributions
         math/statistics
         math/flonum
         "../../main.rkt"
         "../test-utils.rkt")

(printf "starting...~n")

(drbayes-sample-max-splits 0)

(define/drbayes (S)
  (if (boolean (const 0.5)) (T) (F)))

(define/drbayes (T)
  (cond [(boolean (const 0.4))  (cons #t (T))]
        [(boolean (const 0.5))  (cons #t (F))]
        [else  null]))

(define/drbayes (F)
  (cond [(boolean (const 0.4))  (cons #f (F))]
        [(boolean (const 0.5))  (cons #f (let ([s  (T)])
                                           (strict-if (list-ref s (const 1)) (fail) s)))]
        [else  null]))

#;
(let*-values ([(ss ws)  (drbayes-sample (drbayes (S)) 2000)]
              [(ss ws)  (count-samples ss ws)])
  (define d (discrete-dist ss ws))
  (values (discrete-dist-values d)
          (discrete-dist-probs d)))

(let ()
  (define-values (ss ws)
    (let ()
      (define sws
        (time
         (let-values ([(ss ws)
                       (drbayes-sample (drbayes
                                        (let ([s  (S)])
                                          (strict-if (and (list-ref s 1)
                                                          (not (list-ref s 2))
                                                          (list-ref s 3)
                                                          (not (list-ref s 4))
                                                          (list-ref s 5)
                                                          (not (list-ref s 6)))
                                                     s
                                                     (fail))))
                                       2000)])
           (map (inst cons Value Flonum) ss ws))))
      (values (map (inst car Value Flonum) sws)
              (map (inst cdr Value Flonum) sws))))
  
  (printf "DrBayes samples: ~a~n" (length ss))
  (let-values ([(ss ws)  (count-samples ss ws)])
    (discrete-dist ss ws))
  )

(printf "search stats:~n")
(get-search-stats)
(newline)

#|
(printf "cache stats:~n")
(get-cache-stats)
(newline)
|#

;; Racket version of the above, using rejection sampling
(let ()
  (: racket-S (-> (U #f (Listof Boolean))))
  (define (racket-S)
    (if ((random) . < . 0.5) (racket-T) (racket-F)))
  
  (: racket-T (-> (U #f (Listof Boolean))))
  (define (racket-T)
    (cond [((random) . < . 0.4)  (let ([s  (racket-T)]) (and s (cons #t s)))]
          [((random) . < . 0.5)  (let ([s  (racket-F)]) (and s (cons #t s)))]
          [else  null]))
  
  (: racket-F (-> (U #f (Listof Boolean))))
  (define (racket-F)
    (cond [((random) . < . 0.4)  (let ([s  (racket-F)]) (and s (cons #f s)))]
          [((random) . < . 0.5)  (let ([s  (racket-T)])
                                   (and s
                                        (not (empty? s))
                                        (not (empty? (rest s)))
                                        (not (list-ref s 1))
                                        (cons #f s)))]
          [else  null]))
  
  (: ss (Listof (Listof Boolean)))
  (define ss
    (time
     (let: loop : (Listof (Listof Boolean)) ([i : Nonnegative-Fixnum  0])
       (cond [(i . < . 2000)
              (define s (racket-S))
              (match s
                [(list _ #t #f #t #f #t #f _ ...)  (cons (assert s pair?) (loop (+ i 1)))]
                ;[_  (cons (cast s (Listof Boolean)) (loop (+ i 1)))]
                [_  (loop i)])]
             [else
              empty]))))
  
  (printf "Rejection samples: ~a~n" (length ss))
  (let-values ([(ss ws)  (count-samples ss)])
    (discrete-dist ss ws))
  )
