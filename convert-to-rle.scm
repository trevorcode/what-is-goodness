(use-modules (ice-9 popen)
	     (rnrs bytevectors)
	     (rnrs io ports)
	     (ice-9 match))

(display "CONVERTING\n")

(define w 240)
(define h 136)

(define port (open-input-pipe "magick TheDesertNoPoles.png -depth 8 RGB:-"))
(define pixels (get-bytevector-all port))
(close-pipe port)

(define (color->tic80-index rgb)
  (number->string
   (match rgb
     ((0 0 0) 1)
     ((51 51 51) 2)
     ((85 85 85) 3)
     ((119 119 119) 4)
     ((153 153 153) 5)
     ((187 187 187) 6)
     ((221 221 221) 7)
     ((255 255 255) 8))))

(define result 
  (do ((i 0 (+ i 3))
       (result ""))
      ((= i (bytevector-length pixels))
       result)
    (set! result (string-append result (color->tic80-index
					(list (bytevector-u8-ref pixels i)
					      (bytevector-u8-ref pixels (+ i 1))
					      (bytevector-u8-ref pixels (+ i 2))))))))


(define (string->rle str)
  (let ((len (string-length str)))
    (call-with-output-string
      (lambda (port)
	(let loop ((i 0) (count 1))
	  (when (< i len)
	    (if (and (< (+ i 1) len)
		     (< count 9)
		     (char=? (string-ref str i)
			     (string-ref str (+ i 1))))
		(loop (+ i 1) (+ count 1))
		(begin
		  (display count port)
		  (display (string-ref str i) port)
		  (loop (+ i 1) 1)))))))))

(display (string->rle result))


