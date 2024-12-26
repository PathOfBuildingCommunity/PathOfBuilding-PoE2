(define (combine-images-into-sprite-sheet output_path w h saturation coords)
  (let* (
         (sprite-sheet (car (gimp-image-new w h RGB)))
         (layer (car (gimp-layer-new sprite-sheet w h RGBA-IMAGE "Layer" 100 LAYER-MODE-NORMAL)))
        )
    (gimp-image-insert-layer sprite-sheet layer 0 0)

    (define (insert-image img-path x-offset y-offset)
      (gimp-message img-path)
      (let* (
             (layer (car (gimp-file-load-layer RUN-NONINTERACTIVE sprite-sheet img-path)))
            )
        (gimp-image-insert-layer sprite-sheet layer -1 0)
        (gimp-item-set-visible layer TRUE)
        (if (< saturation 100)
          (begin
            (gimp-drawable-hue-saturation layer 0 0 0 (- 0 saturation) 0)
          )
        )
        (gimp-layer-set-offsets layer x-offset y-offset)
      )
    )

    ; Loop through the coordinates to insert images at the specified positions
    (for-each
     (lambda (entry)
       (let* (
              (file (car entry))
              (x (list-ref entry 1))
              (y (list-ref entry 2))
              (w (list-ref entry 3))
              (h (list-ref entry 4))
              )
         (insert-image file x y)
       ))
     coords)

    ; Flatten the image and save as PNG
    (let* (
            (output-jxl (string-append (substring output_path 0 (- (string-length output_path) 4)) ".jxl"))
            (output-webp (string-append (substring output_path 0 (- (string-length output_path) 4)) ".webp"))
            (final-layer (car (gimp-image-merge-visible-layers sprite-sheet CLIP-TO-IMAGE)))
          )
      
      ;; (file-png-export run-mode image file options interlaced compression bkgd offs phys time save-transparent optimize-palette format)
      (file-png-export RUN-NONINTERACTIVE sprite-sheet output_path -1 0 9 1 0 1 1 1 0 "auto")

      ;; (file-jpegxl-export run-mode image file options lossless compression save-bit-depth speed uses-original-profile cmyk save-exif save-xmp)
      (file-jpegxl-export RUN-NONINTERACTIVE sprite-sheet output-jxl -1 0 1 8 "falcon" 0 0 0 0)

      ;; (file-webp-export run-mode image file options preset lossless quality alpha-quality use-sharp-yuv animation-loop minimize-size keyframe-distance default-delay force-delay animation)
      (file-webp-export RUN-NONINTERACTIVE sprite-sheet output-webp -1 "default" 0 100 100 0 0 1 50 200 0 0)
    )
    
    ; Clean up the image object after saving
    (gimp-image-delete sprite-sheet)
  )
)
; Example usage: (combine-images-into-sprite-sheet '("path/to/dds1.dds" "path/to/dds2.dds") "sprite_sheet.png" 1024 1024)
