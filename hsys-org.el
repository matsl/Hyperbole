;;; hsys-org.el --- GNU Hyperbole support functions for Support for hib-org.el
;;
;; Author:       Bob Weiner
;;
;; Orig-Date:     2-Jul-16 at 14:54:14
;;
;; Copyright (C) 2016-2020  Free Software Foundation, Inc.
;; See the "HY-COPY" file for license information.
;;
;; This file is part of GNU Hyperbole.

;;; Commentary:
;;
;;   Support functions for hib-org.el

;;; Code:
;;; ************************************************************************
;;; Other required Elisp libraries
;;; ************************************************************************

(require 'hbut)
(require 'org)

(defcustom inhibit-hsys-org nil
  "*Non-nil means disable Action Key support in Org major and minor modes."
  :type 'boolean
  :initialize #'custom-initialize-default
  :group 'hyperbole-buttons)

(defvar hsys-org-mode-function #'hsys-org-mode-p
  "*Boolean function of no arguments that determines whether point is in an Org mode-related buffer or not.")

;; Make Org-mode's M-RET binding activate implicit buttons
(add-hook 'org-metareturn-hook #'hsys-org-hbut-activate-p)

(defun hsys-org-mode-p ()
  "Return non-nil if point is within an Org major or minor-mode buffer."
  (or (derived-mode-p 'org-mode)
      (derived-mode-p 'org-agenda-mode)
      (and (boundp 'outshine-mode) outshine-mode)
      (and (boundp 'poporg-mode) poporg-mode)))

(defun hsys-org-cycle ()
  "Call `org-cycle' and force it to be set as `this-command' to cycle through all states."
  (setq last-command 'org-cycle
	this-command 'org-cycle)
  (org-cycle))

(defun hsys-org-global-cycle ()
  "Call `org-global-cycle' and force it to be set as `this-command' to cycle through all states."
  (setq last-command 'org-cycle
	this-command 'org-cycle)
  (org-global-cycle nil))

(defun hsys-org-hbut-activate-p ()
  "When within an Org major or minor-mode buffer and `inhibit-hsys-org' is nil (the default), activate any Hyperbole button at point and return t, else return nil."
  (when (and (not inhibit-hsys-org) (funcall hsys-org-mode-function) (hbut:at-p))
    (hbut:act)
    t))

;;; ************************************************************************
;;; Public functions
;;; ************************************************************************

(defun hsys-org-region-with-text-property-value (pos property)
  "Return (start . end) buffer positions of the region around POS that shares its non-nil text PROPERTY value, else nil."
  (when (null pos) (setq pos (point)))
  (let ((property-value (get-text-property pos property))
	(start-point pos))
    (when property-value
      ;; Can't use previous-single-property-change here because it
      ;; ignores characters that lack the property, i.e. have nil values.
      (if (bobp)
	  (setq start-point (point-min))
	(while (equal (get-text-property (1- start-point) property) property-value)
	  (setq start-point (1- start-point))))
      (cons start-point (next-single-property-change start-point property)))))

(defun hsys-org-agenda-item-at-p ()
  "Return non-nil if point is on an Org Agenda item line, else nil."
  (and (derived-mode-p 'org-agenda-mode)
       (org-get-at-bol 'org-marker)))

(defun hsys-org-block-start-at-p ()
  "Return non-nil if point is on the first line of an Org block definition, else nil."
  (save-excursion
    (forward-line 0)
    (or (looking-at org-block-regexp)
	(looking-at org-dblock-start-re))))

(defun hsys-org-link-at-p ()
  "Return non-nil iff point is on an Org mode link.
Assumes caller has already checked that the current buffer is in `org-mode'."
  (or (if (boundp 'org-link-any-re)
	  (org-in-regexp org-link-any-re)
	(org-in-regexp org-any-link-re))
      (hsys-org-face-at-p 'org-link)))

;; Assumes caller has already checked that the current buffer is in org-mode.
(defun hsys-org-target-at-p ()
  "Return non-nil iff point is on an Org mode radio target (definition) or link target (referent).
Assumes caller has already checked that the current buffer is in `org-mode'."
  (hsys-org-face-at-p 'org-target))

(defun hsys-org-radio-target-link-at-p ()
  "Return (target-start . target-end) positions iff point is on an Org mode radio target link (referent), else nil."
  (and (get-text-property (point) 'org-linked-text)
       (hsys-org-link-at-p)
       (hsys-org-region-with-text-property-value (point) 'org-linked-text)))

(defun hsys-org-radio-target-def-at-p ()
  "Return (target-start . target-end) positions iff point is on an Org mode radio target (definition), including any delimiter characters, else nil."
  (when (hsys-org-target-at-p)
    (save-excursion
      (unless (looking-at "<<<")
	(goto-char (or (previous-single-property-change (point) 'face) (point-min))))
      (when (looking-at "<<<")
	(goto-char (match-end 0)))
      (and (get-text-property (point) 'org-linked-text)
	   (hsys-org-region-with-text-property-value (point) 'face)))))

(defun hsys-org-radio-target-at-p ()
  "Return (target-start . target-end) positions iff point is on an Org mode <<<radio target definition>>> or radio target link (referent), including any delimiter characters, else nil."
  (or (hsys-org-radio-target-def-at-p)
      (hsys-org-radio-target-link-at-p)))

(defun hsys-org-internal-link-target-at-p ()
  "Return (target-start . target-end) positions iff point is on an Org mode <<link target>>, including any delimiter characters, else nil."
  (when (hsys-org-target-at-p)
    (save-excursion
      (unless (looking-at "<<")
	(goto-char (or (previous-single-property-change (point) 'face) (point-min))))
      (when (looking-at "<<<?")
	(goto-char (match-end 0)))
      (and (not (get-text-property (point) 'org-linked-text))
	   (hsys-org-region-with-text-property-value (point) 'face)))))

(defun hsys-org-face-at-p (org-face-type)
  "Return ORG-FACE-TYPE iff point is on a character with face ORG-FACE-TYPE, a symbol, else nil."
  (let ((face-prop (get-text-property (point) 'face)))
    (when (or (eq face-prop org-face-type)
	      (and (listp face-prop) (memq org-face-type face-prop)))
      org-face-type)))

(defun hsys-org-search-internal-link-p (target)
  "Search from buffer start for an Org internal link definition matching TARGET.
White spaces are insignificant.  Returns t if a link is found, else nil."
  (when (string-match "<<.+>>" target)
    (setq target (substring target 2 -2)))
  (let ((re (format "%s" (mapconcat #'regexp-quote
			            (split-string target)
			            "[ \t]+\\(?:\n[ \t]*\\)?")))
	(origin (point)))
    (goto-char (point-min))
    (catch :link-match
      (while (re-search-forward re nil t)
	(backward-char)
	(let ((object (org-element-context)))
	  (when (eq (org-element-type object) 'link)
	    (org-show-context 'link-search)
	    (throw :link-match t))))
      (goto-char origin)
      nil)))

(defun hsys-org-search-radio-target-link-p (target)
  "Search from point for a radio target link matching TARGET.
White spaces are insignificant.  Returns t if a target link is found, else nil."
  (when (string-match "<<<.+>>>" target)
    (setq target (substring target 3 -3)))
  (let ((re (format "%s" (mapconcat #'regexp-quote
			            (split-string target)
			            "[ \t]+\\(?:\n[ \t]*\\)?")))
	(origin (point)))
    (catch :radio-match
      (while (re-search-forward re nil t)
	(backward-char)
	(let ((object (org-element-context)))
	  (when (eq (org-element-type object) 'link)
	    (org-show-context 'link-search)
	    (throw :radio-match t))))
      (goto-char origin)
      nil)))

(defun hsys-org-set-ibut-label (start-end)
  "Record the label and START-END positions of any implicit button at point."
  (when (consp start-end)
    (ibut:label-set (ibut:key-to-label
		     (ibut:label-to-key
		      (buffer-substring-no-properties (car start-end) (cdr start-end))))
		    (car start-end) (cdr start-end))))


(defun hsys-org-to-next-radio-target-link (target)
  "Move to the start of the next radio TARGET link if found.  TARGET must be a string."
  (when (string-match "<<<.+>>>" target)
    (setq target (substring target 3 -3)))
  (let ((opoint (point))
	(start-end (hsys-org-radio-target-at-p))
	found)
    (when start-end
      ;; Move past any current target link
      (goto-char (cdr start-end)))
    (while (and (hsys-org-search-radio-target-link-p target)
		(setq found t)
		(not (hsys-org-radio-target-link-at-p))))
    (when found
      (if (hsys-org-radio-target-link-at-p)
	  (goto-char (or (previous-single-property-change (point) 'face) (point-min)))
	(goto-char opoint)))))

;;; ************************************************************************
;;; Private functions
;;; ************************************************************************

(provide 'hsys-org)

;;; hsys-org.el ends here
