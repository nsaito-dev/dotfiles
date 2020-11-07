;; -*- Mode: Emacs-Lisp ; Coding: utf-8 -*-

;****************************************
; Add definition files to load path
;****************************************

;; Default directry is home directory.
(setq default-directory "~/")

;; If emacs version is lower than 23, user-emacs-directory is undefined.
;; If so, user-emacs-directory will be defined.
(when (> emacs-major-version 23)
  (defvar user-emacs-directory "~/.emacs.d"))
;; Function definition for adding load-pah
(defun add-to-load-path (&rest paths)
  (let (path)
    (dolist (path paths paths)
      (let ((default-directory
              (expand-file-name (concat user-emacs-directory path))))
        (add-to-list 'load-path default-directory)
        (if (fboundp 'normal-top-level-add-subdirs-to-load-path)
            (normal-top-level-add-subdirs-to-load-path))))))
;; Add args of directories to loat-path
(add-to-load-path "elisp" "conf" "public_repos")

;****************************************
; Settings for keybind
;****************************************

;; Assign Ctrl-h to back space
(global-set-key "\C-h" 'delete-backward-char)
;; Assign Ctrl-c Ctrl-c to compile
(global-set-key "\C-c\C-c" 'compile)
;; Assign Ctrl-x b to ido-switch-buffer
(global-set-key "\C-xb" 'ido-switch-buffer)
;; Assign M-y to browse-kill-ring
(global-set-key "\M-y" 'browse-kill-ring)
;; Exchange command key and option key when the system is Mac
(when (eq system-type 'darwin)
  (setq ns-command-modifier (quote meta))
  (setq ns-alternate-modifier (quote super)))
;; Assign Ctrl-c u to uncomment-region
(global-set-key "\C-cu" 'uncomment-region)
;; If you type ¥ key, the \ will show
(define-key global-map [?¥] [?\\])
;; Insert licence header
(defun insert-licence-header ()
  (interactive)
  (insert-file "~/.emacs.d/templates/licence-header.txt"))
(global-set-key "\M-l" 'insert-licence-header)
;; Insert compartment line
(defun insert-compartment-line ()
  (interactive)
  (insert "#--------------------------------------------------------------------------------"))
(global-set-key (kbd "M-c") 'insert-compartment-line)

;****************************************
; Settings for font and colors
;****************************************

;; Enable syntax highlight
(global-font-lock-mode t)

;; English font
(if (eq system-type 'darwin) ; If the system is Mac
    (set-face-attribute 'default nil
                        :family "Monaco"
                        :height 120)
  (set-face-attribute 'default nil ; the system is not Mac
                      :family "Consolas"
                      :height 120))
;; Japanese font
(if (eq system-type 'darwin) ; If the system is Mac
    (set-fontset-font nil 'japanese-jisx0208
                      (font-spec :family "Hiragino Mincho Pro"))
  (set-fontset-font nil 'japanese-jisx0208 ; The system is not Mac
                    (font-spec :family "Meiryo")))

;****************************************
; Paren mode settings
;****************************************

;; Delay time for display. default is 0.125 s
(setq show-paren-delay 0)
;; Enable show-paren mode
(show-paren-mode t)
;; Paren style: expression emphasizes internal paren
(setq show-paren-style 'expression)
;; Color in enphasizing internal paren face
;(set-face-background 'show-paren-match-face "slate blue")

;****************************************
; Settings for buffer
;****************************************

;; Display current line number
(setq line-number-mode t)
;; Display current column number
(setq column-number-mode t)
;; Display scroll bar on right side
(set-scroll-bar-mode 'right)
;; Making buffer names unique
(setq uniquify-buffer-name-style 'forward)
;; Region highlight
(setq transient-mark-mode t)
(add-hook 'c-mode-common-hook
          '(lambda()
             ;; Default indent style is cc-mode
             (c-set-style "cc-mode")
             ;; Auto insert specific closing paren
             (make-variable-buffer-local 'skeleton-pair)
             (make-variable-buffer-local 'skeleton-pair-on-word)
             (setq skeleton-pair-on-word t)
             (setq skeleton-pair t)
             (make-variable-buffer-local 'skeleton-pair-alist)
             (local-set-key (kbd "(") 'skeleton-pair-insert-maybe)
             (local-set-key (kbd "[") 'skeleton-pair-insert-maybe)
             (local-set-key (kbd "{") 'skeleton-pair-insert-maybe)
             (local-set-key (kbd "`") 'skeleton-pair-insert-maybe)
             (local-set-key (kbd "\"") 'skeleton-pair-insert-maybe)))
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

;; Tab is not used
(setq-default indent-tabs-mode nil)
;; Indent of tab width is 4 space
(setq-default tab-width 4)
;; Display character and line number in region
(defun count-lines-and-chars ()
  (if mark-active
      (format "%d lines, %d chars "
              (count-lines (region-beginning) (region-end))
              (- (region-end) (region-beginning)))
    ""))
;; (add-to-list 'default-mode-line-format
;;              '(:eval (count-lines-and-chars)))
;; Cua mode
;; Usage: Ctrl-RET
(cua-mode t)  ; Turn on cua mode
(setq cua-enable-cua-keys nil)  ; Disanable cua keybind

;; Remove terminal white spaces at saving
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;****************************************
; Window size
;****************************************
(if (eq system-type 'windows-nt)
    (setq initial-frame-alist
          '((top . 1) (left . 1) (width . 100) (height . 38))))

;****************************************
; Backup settings
;****************************************

;; Enable backup file
(setq make-backup-files t)
;; Enable auto save file
(setq auto-save-default t)
;; Time for making auto save file
(setq auto-save-timeout 15)
;; Time of typing inteval for auto save file
(setq auto-save-interval 60)

;; Make backup directory, when there is not ./.backup.
(defun make-backup-directory ()
  (if (file-directory-p (concat (file-name-directory (buffer-file-name) ) ".backup/"))
      ()
    (make-directory (concat (file-name-directory (buffer-file-name)) ".backup/"))))
(add-hook 'before-save-hook 'make-backup-directory)

;; Add "~" to tauk of backup file.
(defun make-backup-file-name (filename)
  (expand-file-name
   (concat ".backup/" (file-name-nondirectory filename) "~")
   (file-name-directory filename)))

;****************************************
; Auto-install
;****************************************

;; Setting for auto-install
;; Usage: M-x install-elisp RET url RET
(when (require 'auto-install nil t)
  (setq auto-install-directory "~/.emacs.d/elisp/") ; Install directory
 ;(auto-install-update-emacswiki-package-name t)    ; Get elisp registered in emacswiki
  (auto-install-compatibility-setup))               ; Enable install-elisp func

;; ELPA Usage:
;; M-x list-packages      -> display package list
;; M-x package-initialize -> refresh emacs to use extention functions
;;(when (require 'package nil t)
(require 'package)
;; Add Marmalade and official elpa repository to package repository
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(add-to-list 'package-archives '("maralade" . "http://marmalade-repo.org/packages/") t)
;(add-to-list 'package-archives '("ELPA" . "http://tromey.com/elpa/") t)
(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") t)
  ;; Refresh package
(package-initialize)

;****************************************
; Helm
;****************************************

(require 'helm-config)
;(helm-mode 1)

;****************************************
; Auto-complete mode
;****************************************
;; (when (require 'auto-complete-config nil t)
;;   (add-to-list 'ac-dictionary-directories
;;                "~/.emacs.d/elisp/ac-dict")
;;   (define-key ac-mode-map (kbd "M-TAB") 'auto-complete)
;;   (ac-config-default))

;****************************************
; Settings for Script files
;****************************************

;; If file type is script, add executable property to the file
(add-hook 'after-save-hook
          'executable-make-buffer-file-executable-if-script-p)

;; When new file is opened, initial template will be inserted.
(require 'autoinsert)
(setq auto-insert-directory "~/.emacs.d/templates/")
(setq auto-insert-alist
      (nconc '(("\\.py$" . "template.py")
               ("\\.rb$" . "template.rb")
               ("\\.sh$" . "template.sh")
               ("\\.scm$" . "template.scm")
               ("\\.hs$" . "template.hs")
               ("\\.html$" . "template.html")
               (".gitignore$" . "template_gitignore"))
             auto-insert-alist))
(add-hook 'find-file-not-found-hooks 'auto-insert)

;****************************************
; Programing mode settings
;****************************************

;********************
; HTML mode
;********************

;; Set default mode nxml mode
(setq auto-mode-alist (cons '("\\.html$" . nxml-mode) auto-mode-alist))

;; Editting HTML5 on nxml mode
;; add html5-el path to loadpath
(add-to-list 'load-path "~/.emacs.d/public_repos/html5-el/")
;; add schema path
(eval-after-load "rng-loc"
  '(add-to-list 'rng-schema-locating-files
                "~/.emacs.d/public_repos/html5-el/schemas.xml"))
(require 'whattf-dt)

;; nxml-mode hooks
(defun nxml-mode-hooks ()
  ;; auto-closing tag
  (setq nxml-slash-auto-complete-flag t)
  ;; Completion of tag to use M-TAB
  (setq nxml-bind-meta-tab-to-complete-flag t)
  ;; auto-complete mode for nxml mode
  (add-to-list 'ac-modes 'nxml-mode)
  ;; Child indent width is 0, default is 2
  (setq nxml-child-indent 4)
  ;; Attribute indent width is 0, default is 4
  (setq nxml-attribute-indent 4))
(add-hook 'nxml-mode-hook 'nxml-mode-hooks)

;********************
; CSS mode
; Instead of css-mode, using another css mode; cssm-mode.
; cssm-mode was installed by auto-install,
; url is http://www.garshol.priv.no/download/software/css-mode/css-mode.el
;********************

(defun css-mode-hooks ()
  "css-mode hooks"
  ;; Set indent style c-style
  (setq cssm-indent-function #'cssm-c-style-indenter)
  ;; Indent width is 2
  (setq cssm-indent-level 2)
  ;; Tab is not used as indent
  (setq-default indent-tabs-mode nil)
  ;; Insert netline before closing paren
  (setq cssm-newline-before-closing-bracket t)
  ;; auto-complete mode for css-mode
  (add-to-list 'ac-modes 'css-mode))
(add-hook 'css-mode-hook 'css-mode-hooks)

;********************
; JabvaScript mode
; js2-mode was installed by package-install
;********************

(add-to-list 'auto-mode-alist '("\\.js$" . js-mode))

;********************
; Python mode
; python-mode was installed by package-install
;********************

;; auto-complete mode for python mode
(add-hook 'python-mode-hook
          (lambda ()
            (add-to-list 'ac-modes 'python-mode)))

;********************
; Haskell mode
;********************

(require 'haskell-mode)
(require 'haskell-cabal)
(add-to-list 'auto-mode-alist '("\\.hs$" . haskell-mode))
(add-to-list 'auto-mode-alist '("\\.lhs$" . literate-haskell-mode))
(add-to-list 'auto-mode-alist '("\\.cabal\\'" . haskell-cabal-mode))
;; To open a file not having any extensions as haskell mode
(add-to-list 'interpreter-mode-alist '("runghc" . haskell-mode))     ;#!/usr/bin/env runghc
(add-to-list 'interpreter-mode-alist '("runhaskell" . haskell-mode)) ;#!/usr/bin/env runhaskell
(put 'upcase-region 'disabled nil)

;******************************
; For common lisp
;******************************

;; default lisp implementation
(setq inferior-lisp-program "clisp")
;; add SLIME load-path
(add-to-list 'load-path (expand-file-name "~/.emacs.d/public_repos/slime-2013-04-05/"))
;; load SLIME
(require 'slime)
(slime-setup '(slime-repl slime-fancy slime-banner))
;; set SLIME input mode utf-8
(setq slime-net-coding-system 'utf-8-unix)

;; add popwin load path
(add-to-list 'load-path (expand-file-name "~/.emacs.d/public_repos/popwin-el/"))
(require 'popwin)
(setq display-buffer-function 'popwin:display-buffer)
;; popwin settings
;; Apropos
(push '("*slime-apropos*") popwin:special-display-config)
;; Macroexpand
(push '("*slime-macroexpansion*") popwin:special-display-config)
;; Help
(push '("*slime-description*") popwin:special-display-config)
;; Compilation
(push '("*slime-compilation*" :noselect t) popwin:special-display-config)
;; Cross-reference
(push '("*slime-xref*") popwin:special-display-config)
;; Debugger
(push '(sldb-mode :stick t) popwin:special-display-config)
;; REPL
(push '(slime-repl-mode) popwin:special-display-config)
;; Connections
(push '(slime-connection-list-mode) popwin:special-display-config)

;; add ac-slime load path
(add-to-list 'load-path (expand-file-name "~/.emacs.d/public_repos/ac-slime/"))
(require 'ac-slime)
(add-hook 'slime-mode-hook 'set-up-slime-ac)
(add-hook 'slime-repl-mode-hook 'set-up-slime-ac)

;; add cl-indent-patches load-path
(add-to-list 'load-path (expand-file-name "~/.emacs.d/public_repos/cl-indent-patches/"))
(when (require 'cl-indent-patches nil t)
  (setq lisp-indent-function
        (lambda (&rest args)
          (apply (if (memq major-mode '(emacs-lisp-mode lisp-interaction-mode))
                     'lisp-indent-function
                     'common-lisp-indent-function)
                 args))))

;; for fortran mode
(autoload 'fortran-mode "fortran" "major mode for FORTRAN(<=77)" t)
(add-to-list 'auto-mode-alist
             '("\\.\\(f\\|F\\)$" . fortran-mode))
(autoload 'f90-mode "f90" "major mode for FORTRAN(>=90)" t)
(add-to-list 'auto-mode-alist
             '("\\.\\(f90\\|F90\\|f95\\|F95\\|g90\\|g95\\)$" . f90-mode))

;; fortran indent
(setq f90-mode-hook
      '(lambda ()
         (setq f90-do-indent 2
               f90-if-indent 2
               f90-type-indent 2
               f90-program-indent 2
               f90-continuation-indent 2
               f90-indented-comment-re "!"
               f90-comment-region "!!"
               f90-directive-comment-re "!omp\\$"
               f90-break-delimiters "[-+\\*/,><=% \t]"
               f90-break-before-delimiters t
               f90-beginning-ampersand t
               f90-smart-end 'blink
               f90-auto-keyword-case nil
               f90-leave-line-no  nil
               f90-startup-message t
               indent-tabs-mode nil
               f90-font-lock-keywords f90-font-lock-keywords-4)
         ;;The rest is not default.
         (turn-on-font-lock)         ; for highlighting
         (if f90-auto-keyword-case   ; change case of all keywords on startup
             (f90-change-keywords f90-auto-keyword-case))
         ))

;; Server start for emacs-client
(require 'server)
(unless (server-running-p)
  (server-start))


;;; Set color theme
;; make the fringe stand out from the background
;; (setq solarized-distinct-fringe-background t)
;; ;; Don't change the font for some headings and titles
;; (setq solarized-use-variable-pitch nil)
;; ;; make the modeline high contrast
;; (setq solarized-high-contrast-mode-line t)
;; ;; Use less bolding
;; (setq solarized-use-less-bold t)
;; ;; Use more italics
;; (setq solarized-use-more-italic t)
;; ;; Use less colors for indicators such as git:gutter, flycheck and similar
;; (setq solarized-emphasize-indicators nil)
;; ;; Don't change size of org-mode headlines (but keep other size-changes)
;; (setq solarized-scale-org-headlines nil)
;; ;; Avoid all font-size changes
;; (setq solarized-height-minus-1 1.0)
;; (setq solarized-height-plus-1 1.0)
;; (setq solarized-height-plus-2 1.0)
;; (setq solarized-height-plus-3 1.0)
;; (setq solarized-height-plus-4 1.0)
;; (load-theme 'solarized-dark t)

(load-theme 'misterioso t)

;; Server start for emacs-client
(require 'server)
(unless (server-running-p)
  (server-start))

;; Enbale IDO
(ido-mode 1)
(ido-everywhere 1)
(setq ido-enable-flex-matching t)

(defun execute-rietan ()
  (interactive)
  (shell-command-to-string "copy rietan.ins rietan.ins.temp")
  (shell-command-to-string "start rietan.bat"))
(global-set-key "\C-r" 'execute-rietan)

(defun revert-buffer-no-confirm (&optional force-reverting)
  (interactive "P")
  (if (or force-reverting (not (buffer-modified-p)))
      (revert-buffer :igonore-auto :noconfirm)
    (error "The buffer has been modified")))
(global-set-key "\M-r" 'revert-buffer-no-confirm)
