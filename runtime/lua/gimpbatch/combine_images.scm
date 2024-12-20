(define (combine-images-into-sprite-sheet output_path w h saturation coords)
  (let* (
         (sprite-sheet (car (gimp-image-new w h RGB)))
         (layer (car (gimp-layer-new sprite-sheet w h RGBA-IMAGE "Layer" 100 NORMAL-MODE)))
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
      (file-png-save RUN-NONINTERACTIVE sprite-sheet final-layer output_path output_path 0 9 0 1 1 1 1)
      (file-jpegxl-save RUN-NONINTERACTIVE sprite-sheet final-layer output-jxl output-jxl)
      ;; (file-webp-save run-mode image drawable filename raw-filename preset lossless quality alpha-quality animation anim-loop minimize-size kf-distance exif iptc xmp delay force-delay)
      (file-webp-save RUN-NONINTERACTIVE sprite-sheet final-layer output-webp output-webp 0 0 100 100 FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE)
    )
    ; Save the sprite sheet as a PNG
    ; (file-png-save RUN-NONINTERACTIVE sprite-sheet layer output_path output_path 0 9 1 1 1 1 1 1)
    
    ; Clean up the image object after saving
    (gimp-image-delete sprite-sheet)
  )
)
; Example usage: (combine-images-into-sprite-sheet '("path/to/dds1.dds" "path/to/dds2.dds") "sprite_sheet.png" 1024 1024)
