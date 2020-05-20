;; Function to extract a copy/paste-able deck from a .org file:
;; To be called from a <deck>.org file

(defun mtg-debug-printf(string &rest args)
  ;;(apply 'message string args)
  )


(defun mtg-extract-deck()
  (interactive)
  (let ((file-buffer (current-buffer))
	(file-start (point-min))
	(file-end   (point-max))
	(buffer (get-buffer-create "*Deck*")))
    (with-current-buffer buffer
      (erase-buffer)
      (insert-buffer-substring file-buffer file-start file-end)
      (goto-char (point-min))
      ;; Clear the end of the buffer
      (re-search-forward "^|--")
      (delete-region (point-at-bol) (point-max))
      ;; Clear the beginning:
      (goto-char (point-min))
      (re-search-forward "^|")
      (delete-region (point-min) (point-at-bol))
      ;; Delete labels and empty lines
      (goto-char (point-min))
      (while (not (equal (point) (point-max)))
	(if (looking-at "^|[ \t]+|")
	    (let ((start (point-at-bol)))
	      (forward-line 1)
	      (delete-region start (point-at-bol))
	      (goto-char (point-at-bol)))
	    (forward-line 1)))
      ;; Clear unneeded columns
      (goto-char (point-min))
      (while (not (equal (point) (point-max)))
	(re-search-forward "^|[^|]*|[^|]*")
	(delete-region (point) (point-at-eol))
	(goto-char (point-at-bol))
	(re-search-forward "^|[ \t]+")
	(delete-region (point-at-bol) (point))
	(re-search-forward "[ \t]|")
	(delete-char -2)
	(forward-line 1)
	(goto-char (point-at-bol)))
      ;; Final touch:
      (goto-char (point-min))
      (delete-trailing-whitespace (point-min) (point-max))
      (when (looking-at "^1[ \t]")
	(delete-char 2))
      (goto-char (point-at-eol))
      (insert "\n")
      (goto-char (point-min))
      )
   (switch-to-buffer buffer)))

(setq mtg-regexp--title "^|[ ]+|[ ]+\\*[^|]+?\\([0-9]*\\)\\*"
      mtg-regexp--card  "^|[ ]+\\([0-9*?+-]+\\)[ ]+|"
      mtg-regexp--empty "^|[ ]+|[ ]+|")

(defun mtg-update-block-count()
  "Count the number of cards in the current block, update the first line and return the count"
  (interactive)
  (let ((count 0)
	current-count-string
	block-count-pos
	block-count-val
	(saved-init-pos  (point))
	(saved-init-line (line-number-at-pos))
	(saved-init-col  (- (point) (point-at-bol)))
	cur-line)
    (mtg-debug-printf "mtg-update-block-count debugging:")
    (goto-char (point-at-bol))

    (when (or (looking-at mtg-regexp--title)
	      (looking-at mtg-regexp--card)
	      (looking-at mtg-regexp--empty))
      ;; Search for the block title
      (mtg-debug-printf " `- Block found, looking for its title")
      (mtg-debug-printf "    `- line: %s $$ %s"
			(buffer-substring-no-properties (point-at-bol)(min (+(point-at-bol) 20)(point-at-eol)))
			(buffer-substring-no-properties (point) (min (+(point) 20)(point-at-eol))))
      (while (and (not (bobp))
		  (not (looking-at mtg-regexp--title))
		  (or (looking-at mtg-regexp--card)
		      (looking-at mtg-regexp--empty)))
	(forward-line -1)
	(mtg-debug-printf "    `- line: %s $$ %s"
			  (buffer-substring-no-properties (point-at-bol)(min (+(point-at-bol) 20)(point-at-eol)))
			  (buffer-substring-no-properties (point) (min (+(point) 20)(point-at-eol)))))

      ;; Count number of card in the block, recording the block count position
      (when (looking-at mtg-regexp--title)
	(setq block-count-pos (cons (match-beginning 1)
				    (match-end 1))
	      block-count-val (string-to-number (buffer-substring-no-properties (car block-count-pos) (cdr block-count-pos))))
	(mtg-debug-printf " `- Title found, count pos: %s - \"%s\""
			  block-count-pos block-count-val)
	(forward-line)
	(while (and (not (eobp))
		    (looking-at mtg-regexp--card))
	  (setq current-count-string (buffer-substring-no-properties (match-beginning 1)
								     (match-end 1)))
	  (mtg-debug-printf " `- Processing line: %s" current-count-string)
	  (setq count (+ count (or (and (string-equal current-count-string "*") 1)
				   (and (string-equal current-count-string "+") 1)
				   (and (string-equal current-count-string "?") 1)
				   (string-to-number current-count-string))))
	  (forward-line))

	(when (not (= block-count-val count))
	  (let (saved-line cur-line)
	    (setq saved-line (line-number-at-pos))
	    (save-excursion
	      (goto-char (car block-count-pos))
	      (delete-region (car block-count-pos)
			     (cdr block-count-pos))
	      (when (= (car block-count-pos)
		       (cdr block-count-pos))
		(insert " "))
	      (insert (number-to-string count)))
	    (setq cur-line (line-number-at-pos))
	    (when (> cur-line saved-line)
	      (forward-line -1))
	    (when (< cur-line saved-line)
	      (forward-line))
	    ))
	))

    ;; Updating the title if needed:
    (when (called-interactively-p)
      (progn (message "prev count = %s -- new count = %i" block-count-val count)
	     (goto-char saved-init-pos)
	     (if (> (line-number-at-pos) saved-init-line)
		 (forward-line -1))
	     (if (< (line-number-at-pos) saved-init-line)
		 (forward-line))
	     (goto-char (point-at-bol))
	     (forward-char saved-init-col))
	)
    count
    )
  )

(defun mtg-update-all-blocks-count()
  (interactive)
  (let ((count 0)
	(saved-init-pos  (point))
	(saved-init-line (line-number-at-pos))
	(saved-init-col  (- (point) (point-at-bol))))
    (save-excursion
      (goto-char (point-min))
      (while (and (not (eobp))
		  (not (looking-at mtg-regexp--title)))
	(forward-line))
      
      (while (looking-at mtg-regexp--title)
	(setq count (+ count (mtg-update-block-count)))
	(while (and (not (eobp))
		    (or (looking-at mtg-regexp--card)
			(looking-at mtg-regexp--empty)))
	  (forward-line)))
      )
    (goto-char saved-init-pos)
    (if (> (line-number-at-pos) saved-init-line)
	(forward-line -1))
    (if (< (line-number-at-pos) saved-init-line)
	(forward-line))
    (goto-char (point-at-bol))
    (forward-char saved-init-col)
    (message "Deck card count: %i" count)
    )
  )
