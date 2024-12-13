(define (extract-lines-pob src-path-image mask-path-image srcmipmap maskmipmap max-orbits output-path filename extension interactive)
    (let*
        (
            ;; Load the images
            (src-image (car (file-dds-load RUN-NONINTERACTIVE src-path-image src-path-image 1 1)))
            (mask-image (car (file-dds-load RUN-NONINTERACTIVE mask-path-image mask-path-image 1 1)))

            ;; Get the layers
            (layers-src-image (list-ref (gimp-image-get-layers src-image) 1))
            (layers-mask-image (list-ref (gimp-image-get-layers mask-image) 1))

            ;; Get the layer
            (src-layer-id (vector-ref layers-src-image srcmipmap))
            (mask-layer-id (vector-ref layers-mask-image srcmipmap))

            ; get the width and height of the image
            (width-image (car (gimp-drawable-width src-layer-id)))
            (height-image (car (gimp-drawable-height src-layer-id)))

            ;; ui stuff
            (ui-src 0)
            (ui-mask 0)
    
            ; common variables
            (x 0)
            (x0 0)
            (x1 0)
            (y 0)
            (y0 0)
            (y1 0)
            (total 0)
            (current-selection 0)
            (rect 0)
            (next-selection 0)
            (next-rect 0)
            (width 0)
            (height 0)

            (new-image 0)
            (ui-new 0)
            (new-layer 0)
            (dest 0)

            (mask-layer 0)
            (paste-item 0)
            (target-position 0)
            (offset-x 0)
            (offset-y 0)
            (black 0)
            (real-mask 0)
            (position 0)
            (pos-x 0)
            (pos-y 0)
        )


        ;; this is only useful in ui
        (if (= interactive 1)
            (begin
                (gimp-message "loading ui")
                (set! ui-src (car (gimp-display-new src-image)))
                (set! ui-mask (car (gimp-display-new mask-image)))
            )
        )

        (gimp-message "getting the line")
        ;; Get line is rectangle
        (gimp-image-select-contiguous-color mask-image CHANNEL-OP-REPLACE mask-layer-id x y)
        (set! current-selection (gimp-selection-bounds mask-image))
        (set! rect (cdr current-selection))
        (set! y0 (+ (list-ref rect 1) (list-ref rect 3)))
        (gimp-image-select-color mask-image CHANNEL-OP-REPLACE mask-layer-id '(0 0 0 ))
        (gimp-image-select-contiguous-color mask-image CHANNEL-OP-SUBTRACT mask-layer-id x y)
        (set! next-selection (gimp-selection-bounds mask-image))
        (set! next-rect (cdr next-selection))
        (set! y1 (list-ref next-rect 1))
        (set! x0 (list-ref next-rect 0))
        (set! x1 (+ (list-ref next-rect 0) (list-ref next-rect 2)))
        (set! width (- x1 x0))
        (set! height (- y1 y0))
        (gimp-image-select-rectangle src-image CHANNEL-OP-REPLACE x0 y0 width height)

        ;; create the new image with the same size as the rect
        (set! new-image (car (gimp-image-new width height RGB)))
        
        (if (= interactive 1)
            (begin
                (set! ui-new (car (gimp-display-new new-image)))
            )
        )

        (set! new-layer (car (gimp-layer-new new-image width height RGBA-IMAGE "new-layer" 100 LAYER-MODE-NORMAL)))
        (gimp-image-insert-layer new-image new-layer -1 -1)
        (gimp-edit-copy src-layer-id)
        (gimp-floating-sel-anchor (car (gimp-edit-paste new-layer TRUE)))
        (set! dest (string-append output-path filename  (number->string total) extension))
        (file-png-save-defaults RUN-NONINTERACTIVE new-image new-layer dest dest)

        (if (= interactive 1)
            (begin
                (gimp-display-delete ui-new)
            )
        )

        ;; mark with black the line in mask
        (gimp-image-select-rectangle mask-image CHANNEL-OP-REPLACE 0 0 (+ width x0) (+ height y0))
        (gimp-selection-grow mask-image 4)
        (gimp-context-set-foreground '(0 0 0))
        (gimp-edit-fill mask-layer-id FILL-FOREGROUND)

        (gimp-message "getting the orbits")
        ;; getting orbits
        (set! y (+ y1 2))
        (set! total (+ total 1))

        ;; loop to get the orbits
        ;; create a new image
        (while (< total max-orbits)
            (set! new-image (car (gimp-image-new width-image height-image RGB)))

            (if (= interactive 1)
                (begin
                    (set! ui-new (car (gimp-display-new new-image)))
                )
            )

            (set! new-layer (car (gimp-layer-new new-image width-image height-image RGBA-IMAGE "new-layer" 100 LAYER-MODE-NORMAL)))
            (gimp-image-insert-layer new-image new-layer -1 -1)
            (gimp-selection-none src-image)
            (gimp-edit-copy src-layer-id)
            (gimp-floating-sel-anchor (car (gimp-edit-paste new-layer TRUE)))

            ;; add new mask layer to the new image
            (set! mask-layer (car (gimp-layer-new new-image width-image height-image RGBA-IMAGE "mask" 100 LAYER-MODE-NORMAL)))
            (gimp-context-set-foreground '(255 255 255))
            (gimp-image-insert-layer new-image mask-layer -1 -1)
            (gimp-edit-fill mask-layer FILL-FOREGROUND)

            ;; select next orbit
            (gimp-image-select-contiguous-color mask-image CHANNEL-OP-REPLACE mask-layer-id (- width-image 2) (+ y 2))
            (set! next-selection (gimp-selection-bounds mask-image))
            (set! next-rect (cdr next-selection))
            (gimp-edit-copy mask-layer-id)
            (set! paste-item (car (gimp-edit-paste mask-layer TRUE)))
            (set! target-position (gimp-drawable-offsets paste-item))
            (set! offset-x (car target-position))
            (set! offset-y (car (cdr target-position)))
            (gimp-layer-translate paste-item (- (list-ref next-rect 0) offset-x) (- (list-ref next-rect 1) offset-y))
            (gimp-floating-sel-anchor paste-item)

            ;; find the next rectangle
            (gimp-image-select-color mask-image CHANNEL-OP-REPLACE mask-layer-id '(0 0 0 ))
            (gimp-image-select-contiguous-color mask-image CHANNEL-OP-SUBTRACT mask-layer-id (- width-image 2) (+ y 2))

            ;; get bounds
            (set! next-selection (gimp-selection-bounds mask-image))
            (set! next-rect (cdr next-selection))
            (set! y (list-ref next-rect 1))

            (gimp-image-select-contiguous-color mask-image CHANNEL-OP-REPLACE mask-layer-id (- width-image 2) (+ y 2))
            (set! next-selection (gimp-selection-bounds mask-image))
            (set! next-rect (cdr next-selection))

            ;; copy next selection
            (gimp-edit-copy mask-layer-id)
            (set! paste-item (car (gimp-edit-paste mask-layer TRUE)))
            (set! target-position (gimp-drawable-offsets paste-item))
            (set! offset-x (car target-position))
            (set! offset-y (car (cdr target-position)))
            (gimp-layer-translate paste-item (- (list-ref next-rect 0) offset-x) (- y offset-y))
            (gimp-floating-sel-anchor paste-item)

            ;; close the image for magic selection
            (gimp-context-set-foreground '(0 0 0))
            (gimp-image-select-rectangle new-image CHANNEL-OP-REPLACE (- width-image 1) 0 width-image height-image)
            (gimp-edit-fill mask-layer FILL-FOREGROUND)

            (gimp-image-select-rectangle new-image CHANNEL-OP-REPLACE 0 (- height-image 1) width-image height-image)
            (gimp-edit-fill mask-layer FILL-FOREGROUND)

            ;; fill bottom transparent with black 
            (gimp-image-select-contiguous-color new-image CHANNEL-OP-REPLACE mask-layer (- width-image 2) (- height-image 2))
            (gimp-selection-grow new-image 4)
            (gimp-edit-fill mask-layer FILL-FOREGROUND)

            (gimp-selection-none new-image)

            ;; take black part and add top bart copy and paste in mask-layer-id
            (gimp-image-select-color new-image CHANNEL-OP-REPLACE mask-layer '(255 255 255))
            (gimp-selection-grow new-image 4)
            (set! black (cdr (gimp-selection-bounds new-image)))
            (gimp-edit-copy mask-layer)
            (set! paste-item (car (gimp-edit-paste mask-layer-id FALSE)))
            (set! target-position (gimp-drawable-offsets paste-item))
            (set! offset-x (car target-position))
            (set! offset-y (car (cdr target-position)))
            (gimp-layer-translate paste-item (- (list-ref black 0) offset-x) (- (list-ref black 1) offset-y))
            (gimp-context-set-foreground '(0 0 0))
            (gimp-edit-fill paste-item FILL-FOREGROUND)
            (gimp-floating-sel-anchor paste-item)

            ;; create the mask
            (set! real-mask (car (gimp-layer-create-mask new-layer ADD-BLACK-MASK)))
            (gimp-layer-add-mask new-layer real-mask)

            (gimp-edit-copy mask-layer)
            (gimp-floating-sel-anchor (car (gimp-edit-paste real-mask TRUE)))

            (gimp-layer-set-visible mask-layer FALSE)
            (set! new-layer (car (gimp-image-merge-visible-layers new-image EXPAND-AS-NECESSARY)))

            ;; redefine the new layer
            (gimp-image-select-contiguous-color new-image CHANNEL-OP-REPLACE new-layer 0 0)
            (gimp-selection-invert new-image)
            (set! position (cdr (gimp-selection-bounds new-image)))
            (set! pos-x (list-ref position 0))
            (set! pos-y (list-ref position 1))
            (gimp-layer-translate new-layer (- 0 pos-x) (- 0 pos-y))
            (gimp-image-resize new-image (- width-image pos-x) (- height-image pos-y) 0 0)

            ;; save the image
            (set! dest (string-append output-path filename  (number->string total) extension))
            (file-png-save-defaults RUN-NONINTERACTIVE new-image new-layer dest dest)

            (if (= interactive 1)
                (begin
                    (gimp-display-delete ui-new)
                )
                (begin
                    (gimp-image-delete new-image)
                )
            )

            (set! y (list-ref next-rect 1))
            (set! total (+ total 1))
        )
        ;; end loop

        ;; cleanup
        ;; remove ui
        (if (= interactive 1)
            (begin
                (gimp-display-delete ui-src)
                (gimp-display-delete ui-mask)
            )
            (begin
                ;; this remove images if not ui
                (gimp-image-delete src-image)
                (gimp-image-delete mask-image)        
            )
        )
    )
)