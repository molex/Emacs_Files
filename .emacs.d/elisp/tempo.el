;;; tempo.el --- templates with hotspots

;; Copyright (C) 1994 David Kågedal

;; Author: David Kågedal <davidk@lysator.liu.se>
;; Created: 16 Feb 1994
;; Version: $Id: tempo.el,v 1.3 1994/03/02 23:55:52 davidk Exp $  1.0b4
;; Keywords: template skeleton

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;; LCD Archive Entry:
;; tempo.el|David Kågedal|davidk@lysator.liu.se|
;; Flexible template creation for major and minor modes|
;; 2-Mar-94|1.0b4|

;;; Commentary:

;; This file provides a simple way to define powerful templates, or
;; macros, if you wish. It is mainly intended for, but not limited to,
;; other programmers to be used for creating shortcuts for editing
;; certain kind of documents. It was originally written to be used by
;; a HTML editing mode written by Nelson Minar <nelson@reed.edu>, and
;; his html-helper-mode.el is probably the best example of how to use
;; this program.

;; A template is defined as a list of items to be inserted in the
;; current buffer at point. Some of the items can be simple strings,
;; while other can control formatting or define special points of
;; interest in the inserted text.

;; If a template defines a "point of interest" that point is inserted
;; in a buffer-local list of "points of interest" that the user can
;; jump between with the commands `tempo-backward-mark' and
;; `tempo-forward-mark'. If the template definer provides a prompt for
;; the point, and the variable `tempo-interactive' is non-nil, the
;; user will be prompted for a string to be inserted in the buffer,
;; using the minibuffer.

;; The template can also define one point to be replaced with the
;; current region if the template command is called with a prefix (or
;; a non-nil argument).

;; More flexible templates can be created by including lisp symbols,
;; which will be evaluated as variables, or lists, which will will be
;; evaluated as lisp expressions.

;; See the documentation for tempo-define-template for the different
;; items that can be used to define a tempo template.

;; One of the more powerful features of tempo templates are automatic
;; completion. With every template can be assigned a special tag that
;; should be recognized by `tempo-complete-tag' and expanded to the
;; complete template. By default the tags are added to a global list
;; of template tags, and are matched against the last word before
;; point. But if you assign your tags to a specific list, you can also
;; specify another method for matching text in the buffer against the
;; tags. In the HTML mode, for instance, the tags are matched against
;; the text between the last `<' and point.

;; When defining a template named `foo', a symbol named
;; `tempo-template-foo' will be created whose value as a variable will
;; be the template definition, and its function value will be an
;; interactive function that inserts the template at the point.

;; Full documentation for tempo.el can be found on the World Wide Web
;; at http://www.lysator.liu.se:7500/~davidk/tempo.html

;;; Code:

(provide 'tempo)

;;; Variables

(defvar tempo-interactive nil
  "*Prompt user for strings in templates.

If this variable is non-nil, `tempo-insert' will try to prompt the
user for text to insert in the templates")

(defvar tempo-insert-string-hook nil
  " Hooks to run when inserting a string. Every hook is called with a
single arg STRING."  )

(defvar tempo-tags nil
  "An association list with tags and corresponding templates")

(defvar tempo-local-tags '((tempo-tags . nil))
  "A list of locally installed tag completion lists.

It is a association list where the car of every element is a symbol
whose varable value is a template list. The cdr part, if non-nil, is a
function or a regexp that defines the string to match. See the
documentation for the function `tempo-complete-tag' for more info.

`tempo-tags' is always in the last position in this list.")

(defvar tempo-marks nil
  "A list of marks to jump to with `\\[tempo-forward-mark]' and `\\[tempo-backward-mark]'")

(defvar tempo-default-match-finder "\\b\\([^\\b]*\\)\\="
  "The default regexp used in `tempo-complete-tag' to find the string to
match against the tags.")

;; Make some variables local to every buffer

(make-variable-buffer-local 'tempo-marks)
(make-variable-buffer-local 'tempo-local-tags)

;;; Functions

;;
;; tempo-define-template

(defun tempo-define-template (name elements &optional tag documentation taglist)
  "Define a template.

This function creates a template variable `tempo-template-NAME' and an
interactive function `tempo-template-NAME' that inserts the template
at the point. The created function is returned.

NAME is a string that contains the name of the template, ELEMENTS is a
list of elements in the template, TAG is the tag used for completion,
DOCUMENTATION is the documentation string for the insertion command
created, and TAGLIST (a symbol) is the tag list that TAG (if provided)
should be added to). If TAGLIST is nil and TAG is non-nil, TAG is
added to `tempo-tags'

The elements in ELEMENTS can be of several types:

 - A string. It is sent to the hooks in `tempo-insert-string-hook',
   and the result is inserted.
 - The symbol 'p. This position is saved in `tempo-marks'.
 - The symbol 'r. If `tempo-insert' is called with ON-REGION non-nil
   the current region is placed here. Otherwise it works like 'p.
 - (p . PROMPT) If `tempo-interactive' is non-nil, the user is
   prompted in the minbuffer with PROMPT for a string to be inserted.
   If `tempo-interactive is nil, it works like 'p.
 - (r . PROMPT) like the previou, but if `tempo-interactive' is nil
   and `tempo-insert' is called with ON-REGION non-nil, the current
   region is placed here.
 - '& If there is only whitespace between the line start and point,
   nothing happens. Otherwise a newline is inserted.
 - '> The line is indented using `indent-according-to-mode'. Note that
   you will probably want to place this item after the text you want
   on the line
 - nil. It is ignored.
 - Anything else. It is evaluated and the result is parsed again."

  (let* ((template-name (intern (concat "tempo-template-"
				       name)))
	 (command-name template-name))
    (set template-name elements)
    (fset command-name (list 'lambda (list '&optional 'arg)
			     (or documentation 
				 (concat "Insert a " name "."))
			     (list 'interactive "*P")
			     (list 'tempo-insert-template (list 'quote
						       template-name)
				   'arg)))
    (and tag
	 (tempo-add-tag tag template-name taglist))
    command-name))

;;;
;;; tempo-insert-template

(defun tempo-insert-template (template on-region)
  "Insert a template.

TEMPLATE is the template to be inserted. If ON-REGION is non-nil the
`r' elements are replaced with the current region."

  (and on-region
       (< (mark) (point))
       (exchange-point-and-mark))
  (save-excursion
    (tempo-insert-mark (point-marker))
    (mapcar 'tempo-insert 
	    (symbol-value template))
    (tempo-insert-mark (point-marker)))
  (tempo-forward-mark))

;;;
;;; tempo-insert

(defun tempo-insert (element) 
  "Insert a template element.

Insert one element from a template. See documentation for
`tempo-define-template' for the kind of elements possible."
  (cond ((stringp element) (tempo-process-and-insert-string element))
	((and (consp element) (eq (car element) 'p))
	 (tempo-insert-prompt (cdr element)))
	((and (consp element) (eq (car element) 'r))
	 (if on-region
	     (exchange-point-and-mark)
	   (tempo-insert-prompt (cdr element))))
	((eq element 'p) (tempo-insert-mark (point-marker)))
	((eq element 'r) (if on-region
			(exchange-point-and-mark)
		      (tempo-insert-mark (point-marker))))
	((eq element '>) (indent-according-to-mode))
	((eq element '&) (if (not (or (= (current-column) 0)
				      (save-excursion (re-search-backward "^\\s-*\\=" nil t))))
			     (newline)))
	((null element))
	(t (tempo-insert (eval element)))))

;;;
;;; tempo-insert-prompt

(defun tempo-insert-prompt (prompt)
  "Prompt for a text string and insert it in the current buffer.

If the variable `tempo-interactive' is non-nil the user is prompted
for a string in the minibuffer, which is then inserted in the current
buffer. If `tempo-interactive' is nil, the current point is placed on
`tempo-forward-mark-list'.

PROMPT is the prompt string."
(if tempo-interactive
    (insert (read-string prompt))
  (tempo-insert-mark (point-marker))))

;;;
;;; tempo-process-and-insert-string

(defun tempo-process-and-insert-string (string)
  "Insert a string from a template.

Run a string through the preprocessors in `tempo-insert-string-hooks'
and insert the results."

  (cond ((null tempo-insert-string-hook)
	 nil)
	((symbolp tempo-insert-string-hook)
	 (setq string
	       (apply tempo-insert-string-hook (list string))))
	((listp tempo-insert-string-hook)
	 (mapcar (function (lambda (fn)
			     (setq string (apply fn string))))
		 tempo-insert-string-hook))
	(t
	 (error "Bogus value in tempo-insert-string-hook: %s"
		tempo-insert-string-hook)))
  (insert string))

;;;
;;; tempo-insert-mark

(defun tempo-insert-mark (mark)
  "Insert a mark `tempo-marks' while keeping it sorted"
  (cond ((null tempo-marks) (setq tempo-marks (list mark)))
	((< mark (car tempo-marks)) (setq tempo-marks (cons mark tempo-marks)))
	(t (let ((lp tempo-marks))
	     (while (and (cdr lp)
			 (<= (car (cdr lp)) mark))
	       (setq lp (cdr lp)))
	     (if (not (= mark (car lp)))
		 (setcdr lp (cons mark (cdr lp))))))))
	  
;;;
;;; tempo-forward-mark

(defun tempo-forward-mark ()
  "Jump to the next mark in `tempo-forward-mark-list'."
  (interactive)
  (let ((next-mark (catch 'found
		     (mapcar
		      (function
		       (lambda (mark)
			 (if (< (point) mark)
			     (throw 'found mark))))
		      tempo-marks)
		     ;; return nil if not found
		     nil)))
    (if next-mark
	(goto-char next-mark))))

;;;
;;; tempo-backward-mark

(defun tempo-backward-mark ()
  "Jump to the previous mark in `tempo-back-mark-list'."
  (interactive)
  (let ((prev-mark (catch 'found
		     (let (last)
		       (mapcar
			(function
			 (lambda (mark)
			   (if (<= (point) mark)
			       (throw 'found last))
			   (setq last mark)))
			tempo-marks)
		       last))))
    (if prev-mark
	(goto-char prev-mark))))
	
;;;
;;; tempo-add-tag

(defun tempo-add-tag (tag template &optional tag-list)
  "Add a template tag.

Add the TAG, that should complete to TEMPLATE to the list in TAG-LIST,
or to `tempo-tags' if TAG-LIST is nil."

  (interactive "sTag: \nCTemplate: ")
  (if (null tag-list)
      (setq tag-list 'tempo-tags))
  (if (not (assoc tag (symbol-value tag-list)))
      (set tag-list (cons (cons tag template) (symbol-value tag-list)))))

;;;
;;; tempo-use-tag-list

(defun tempo-use-tag-list (tag-list &optional completion-function)
  "Install TAG-LIST to be used for template completion in the current buffer.

TAG-LIST is a symbol whose variable value is a tag list created with
`tempo-add-tag' and COMPLETION-FUNCTION is an optional function or
string that is used by `\\[tempo-complete-tag]' to find a string to
match the tag against.

If COMPLETION-FUNCTION is a string, it should contain a regular
expression with at least one \\( \\) pair. When searching for tags,
`tempo-complete-tag' calls `re-search-backward' with this string, and
the string between the first \\( and \\) is used for matching against
each string in the tag list. If one is found, the whole text between
the first \\( and the point is replaced with the inserted template.

You will probably want to include \\ \= at the end of the regexp to make
sure that the string is matched only against text adjacent to the
point.

If COPMLETION-FUNCTION is a symbol, it should be a function that
returns a cons cell of the form (STRING . POS), where STRING is the
string used for matching and POS is the buffer position after which
text should be replaced with a template."

  (let ((old (assq tag-list tempo-local-tags)))
    (if old
	(setcdr old completion-function)
      (setq tempo-local-tags (cons (cons tag-list completion-function)
				   tempo-local-tags)))))

;;;
;;; tempo-find-match-string

(defun tempo-find-match-string (finder)
  "Find a string to be matched against a tag list.

FINDER is a function or a string. Returns (STRING . POS)."
  (cond ((stringp finder)
	 (save-excursion
	   (re-search-backward finder nil t))
	 (cons (buffer-substring (match-beginning 1) (1+ (match-end 1)))
	       (match-beginning 1)))
	(t
	 (funcall finder))))

;;;
;;; tempo-complete-tag

(defun tempo-complete-tag (&optional silent)
  "Look for a tag and expand it..

It goes through the tag lists in `tempo-local-tags' (this includes
`tempo-tags') and for each list it uses the corresponding match-finder
function, or `tempo-default-match-finder' if none is given, and tries
to match the match string against the tags in the list using
`try-completion'. If none is found it proceeds to the next list until
one is found. If a partial completion is found, it is replaced by the
template if it can be completed uniquely, or completed as far as
possible.

When doing partial completion, only tags in the currently examined
list are considered, so if you provide similar tags in different lists
in `tempo-local-tags', the result may not be desirable.

If no match is found or a partial match is found, and SILENT is
non-nil, the function will give a signal."

  (interactive)
  (if (catch 'completed
	(mapcar
	 (function
	  (lambda (tag-list-a)
	    (let* ((tag-list (symbol-value(car tag-list-a)))
		   (match-string-finder (or (cdr tag-list-a)
					    tempo-default-match-finder))
		   (match-info (tempo-find-match-string match-string-finder))
		   (match-string (car match-info))
		   (match-start (cdr match-info))
		   (compl (or (cdr (assoc match-string tag-list))
			      (try-completion (car match-info)
					      tag-list))))
	
	      (if compl			;any match
		  (delete-region match-start (point)))

	      (cond
	       ((null compl)
		nil)
	       ((symbolp compl)
		(tempo-insert-template compl nil)
		(throw 'completed t))
	       ((eq compl t)
		(tempo-insert-template (cdr (assoc match-string tag-list))
				       nil)
		(throw 'completed t))
	       ((stringp compl)
		(let ((compl2 (assoc compl tag-list)))
		  (if compl2
		      (tempo-insert-template (cdr compl2) nil)
		    (insert compl)
		    (if (string= match-string compl)
			(if (not silent)
			    (ding)))))
		(throw 'completed t))))))
	 tempo-local-tags)
	;; No completion found. Return nil
	nil)
      ;; Do nothing if a completion was found
      nil
    ;; No completion was found
    (if (not silent)
	(ding))))

;;; tempo.el ends here
