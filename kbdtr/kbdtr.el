;;; kbdtr.el --- Eyelash Corne keymap in Emacs: a cheat sheet and the layers -*- lexical-binding: t -*-

;; Reads what ./kb writes after every flash and on `./kb index':
;;   out/index.json   how to type each char, per input source
;;   out/layers.json  the layers as text, per input source
;;
;; `kbdtr-find' searches a char by itself or its Unicode name (&, brace, э),
;; shows how to type it and copies it: the rows of the Cmd+Alt+A cheat sheet.
;; `kbdtr-layers' shows the layers that type in the current input source.
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

(defvar-keymap kbdtr-layers-mode-map
  :parent special-mode-map
  "l" #'kbdtr-layers-other-source
  "f" #'kbdtr-find)

(define-derived-mode kbdtr-layers-mode special-mode "kbdtr"
  "The keymap's layers as text, as they type in one input source."
  (setq truncate-lines t
        header-line-format " l — другая раскладка   f — найти символ   g — перечитать   q — закрыть")
  (setq-local font-lock-defaults '(kbdtr--layers-font-lock t)
              revert-buffer-function (lambda (&rest _) (kbdtr--layers-show kbdtr--layers-source))))

(defun kbdtr--layers-show (source)
  "Fill the current buffer with the layers that type in SOURCE."
  (let ((inhibit-read-only t)
        (pos (point)))
    (erase-buffer)
    (insert (alist-get (intern source) (kbdtr--read "layers.json")))
    (goto-char (min pos (point-max)))
    (setq kbdtr--layers-source source)))

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
