;;; kbdtr.el --- Eyelash Corne keymap in Emacs: a cheat sheet and the layers -*- lexical-binding: t -*-

;; Reads what ./kb writes after every flash and on `./kb index':
;;   out/index.json   how to type each char, per input source
;;   out/layers.json  the layers as text, per input source
;;
;; `kbdtr-find' searches a char by itself or its Unicode name (&, brace, э),
;; shows how to type it and copies it: the rows of the Cmd+Alt+A cheat sheet.
;; `kbdtr-layers' shows the layers that type in the current input source;
;; there h tints the keys by how often the keystroke log says they are
;; pressed, and g runs kb index to recount.
;;
;; Nothing here needs macOS.  The input source comes from the keystroke
;; logger when Hammerspoon pushes it there (~/.emacs.d/lisp/init-keystroke-log.el),
;; else from the last letter before point.

(defvar kbdtr-dir (file-name-directory (or load-file-name buffer-file-name))
  "The kbdtr checkout; kb writes into out/ under it.")

(defconst kbdtr--sources '("ABC" "RussianWin")
  "Input sources kb writes rows for, as macOS names them.")

(defvar-local kbdtr--layers-source nil
  "Input source the *kbdtr* buffer shows.")

(defun kbdtr--read (file)
  "Parse out/FILE, written by kb."
  (let ((path (expand-file-name (concat "out/" file) kbdtr-dir)))
    (unless (file-exists-p path)
      (user-error "Нет %s: запусти %skb index" path kbdtr-dir))
    (with-temp-buffer
      (insert-file-contents path)
      (json-parse-buffer :object-type 'alist :array-type 'list))))

(defun kbdtr--source ()
  "Input source typed in now: \"ABC\" or \"RussianWin\".
Exact when Hammerspoon pushes it into the keystroke logger (macOS);
elsewhere the script of the last letter before point decides."
  (let ((pushed (bound-and-true-p my/klog--layout)))
    (cond (kbdtr--layers-source)
          ((member pushed kbdtr--sources) pushed)
          ((save-excursion
             (and (re-search-backward "[[:alpha:]]" (max (point-min) (- (point) 5000)) t)
                  (eq (aref char-script-table (char-after)) 'cyrillic)))
           "RussianWin")
          (t "ABC"))))

(defun kbdtr--other (source)
  "The input source that is not SOURCE."
  (car (remove source kbdtr--sources)))

(defun kbdtr-find (&optional other)
  "Pick a char by itself or its Unicode name, see how to type it, copy it.
The ways are for the current input source; with OTHER
\(\\[universal-argument]), for the other one."
  (interactive "P")
  (let* ((source (if other (kbdtr--other (kbdtr--source)) (kbdtr--source)))
         (rows (make-hash-table :test #'equal)))
    (dolist (row (alist-get (intern source) (kbdtr--read "index.json")))
      (puthash (alist-get 'text row) row rows))
    (let* ((completion-extra-properties
            (list :annotation-function
                  (lambda (text)
                    (concat "   " (propertize (alist-get 'subText (gethash text rows))
                                              'face 'completions-annotations)))))
           (row (gethash (completing-read (format "Как набрать (%s): " source) rows nil t)
                         rows)))
      (kill-new (alist-get 'char row))
      (message "%s   %s" (alist-get 'text row) (alist-get 'subText row)))))

(defconst kbdtr--layers-font-lock
  '(("^[[:upper:]].*" . 'bold)          ; layer titles: "QWERTY · RussianWin"
    ("^combo" . 'shadow)
    ("^▽.*" . 'shadow))                 ; the legend
  "Faces of *kbdtr*.  Keywords only: a \" key must not start a string.")

(defvar-local kbdtr--layers-heat nil
  "Non-nil when *kbdtr* tints keys and combos by how often they are pressed.")

(defvar-keymap kbdtr-layers-mode-map
  :parent special-mode-map
  "l" #'kbdtr-layers-other-source
  "h" #'kbdtr-layers-heat
  "f" #'kbdtr-find)

(define-derived-mode kbdtr-layers-mode special-mode "kbdtr"
  "The keymap's layers as text, as they type in one input source."
  (setq truncate-lines t
        header-line-format (concat " l — другая раскладка   h — частота нажатий"
                                   "   f — найти символ   g — пересчитать   q — закрыть"))
  (setq-local font-lock-defaults '(kbdtr--layers-font-lock t)
              ;; Tap lines keep trailing spaces, so the rightmost keys tint whole.
              show-trailing-whitespace nil
              revert-buffer-function (lambda (&rest _) (kbdtr-layers-refresh))))

(defun kbdtr--layers-show (source)
  "Fill the current buffer with the layers that type in SOURCE."
  (let* ((inhibit-read-only t)
         (pos (point))
         (data (kbdtr--read "layers.json"))
         (view (alist-get (intern source) data)))
    (erase-buffer)
    (remove-overlays)
    (insert (alist-get 'text view))
    (when kbdtr--layers-heat
      (kbdtr--tint (alist-get 'cells view) (alist-get 'colors data)))
    (goto-char (min pos (point-max)))
    (setq kbdtr--layers-source source)))

(defun kbdtr--tint (cells colors)
  "Tint CELLS, lists (LINE COL WIDTH INDEX), with COLORS, light to dark.
LINE counts from 0 and COL in chars, as kb writes them."
  (save-excursion
    (dolist (cell cells)
      (pcase-let ((`(,line ,col ,width ,i) cell))
        (goto-char (point-min))
        (forward-line line)
        (overlay-put (make-overlay (+ (point) col) (+ (point) col width))
                     'face (list :background (nth i colors)
                                 :foreground (if (< i 5) "black" "white")))))))

(defun kbdtr-layers-heat ()
  "Tint keys and combos by how often they are pressed, or stop tinting."
  (interactive)
  (setq kbdtr--layers-heat (not kbdtr--layers-heat))
  (kbdtr--layers-show kbdtr--layers-source)
  (message (if kbdtr--layers-heat
               "Чем темнее, тем чаще клавиша нажата на своём слое (по логу Emacs, на момент kb index)"
             "Подсветка выключена")))

(defun kbdtr-layers-refresh ()
  "Run kb index for fresh press counts, then show the layers again."
  (interactive)
  (let ((buf (current-buffer))
        (out (get-buffer-create " *kb index*")))
    (with-current-buffer out (erase-buffer))
    (message "kb index…")
    (make-process
     :name "kb index" :buffer out
     :command (list (expand-file-name "kb" kbdtr-dir) "index")
     :sentinel (lambda (proc _event)
                 (unless (process-live-p proc)
                   (cond ((/= (process-exit-status proc) 0)
                          (message "kb index упал: %s"
                                   (with-current-buffer out (string-trim (buffer-string)))))
                         ((buffer-live-p buf)
                          (with-current-buffer buf
                            (kbdtr--layers-show kbdtr--layers-source))
                          (message "kb index: готово"))))))))

(defun kbdtr-layers (&optional other)
  "Show the layers as they type in the current input source.
With OTHER (\\[universal-argument]), in the other one."
  (interactive "P")
  (let ((source (if other (kbdtr--other (kbdtr--source)) (kbdtr--source))))
    (with-current-buffer (get-buffer-create "*kbdtr*")
      (unless (derived-mode-p 'kbdtr-layers-mode)
        (kbdtr-layers-mode))
      (kbdtr--layers-show source)
      (goto-char (point-min))
      (pop-to-buffer (current-buffer)))))

(defun kbdtr-layers-other-source ()
  "Show the layers of the other input source."
  (interactive)
  (kbdtr--layers-show (kbdtr--other kbdtr--layers-source)))

(provide 'kbdtr)
;;; kbdtr.el ends here
