(define (combine-dds-into-sprite-sheet output_path w h saturation coords)
  (let* (
         (sprite-sheet (car (gimp-image-new w h RGB)))
         (layer (car (gimp-layer-new sprite-sheet w h RGBA-IMAGE "Layer" 100 NORMAL-MODE)))
        )
    (gimp-image-insert-layer sprite-sheet layer 0 0)

    (define (insert-image img-path x-offset y-offset mipmap)
      (gimp-message img-path)
      (let* (
             ;;(loaded-image (car (gimp-file-load-layer image file-path file-path)))
             (loaded-image (car (file-dds-load RUN-NONINTERACTIVE img-path img-path 1 1)))
             (layers-image (list-ref (gimp-image-get-layers loaded-image) 1))
             (layer-id (vector-ref layers-image mipmap))
             (layer (car (gimp-layer-new-from-drawable layer-id sprite-sheet)))
            )
        (gimp-image-insert-layer sprite-sheet layer -1 0)
        (gimp-item-set-visible layer TRUE)
        (if (< saturation 100)
          (begin
            (gimp-drawable-hue-saturation layer 0 0 0 (- 0 saturation) 0)
          )
        )
        (gimp-layer-set-offsets layer x-offset y-offset)
        (gimp-image-delete loaded-image)
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
              (mipmap (list-ref entry 5))
              )
         (insert-image file x y mipmap)
       ))
     coords)

    ; Flatten the image and save as PNG
    (let* (
           (final-layer (car (gimp-image-merge-visible-layers sprite-sheet CLIP-TO-IMAGE)))
          )
      (file-png-save RUN-NONINTERACTIVE sprite-sheet final-layer output_path output_path 0 9 0 1 1 1 1)
    )
    ; Save the sprite sheet as a PNG
    ; (file-png-save RUN-NONINTERACTIVE sprite-sheet layer output_path output_path 0 9 1 1 1 1 1 1)
    
    ; Clean up the image object after saving
    (gimp-image-delete sprite-sheet)
  )
)
; Example usage: (combine-dds-into-sprite-sheet '("path/to/dds1.dds" "path/to/dds2.dds") "sprite_sheet.png" 1024 1024)
