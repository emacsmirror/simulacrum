;;; simulacrum.el --- Inject custom event types into the event stream  -*- lexical-binding: t; -*-

;; Copyright (C) 2025, 2026  Erik Präntare

;; Author: Erik Präntare
;; Version: 1.0.0
;; Homepage: https://github.com/ErikPrantare/simulacrum.el
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience
;; Created: 19 Aug 2025

;; simulacrum.el is free software; you can redistribute it and/or
;; modify it under the terms of the GNU Affero General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; simulacrum.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public
;; License along with this program.  If not, see
;; <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Emacs input events are limited to keys, mouse actions, and a few
;; special types.  Simulacrum extends this by letting you define custom
;; event types that carry arbitrary data.  This is useful when an
;; external process (e.g., a voice control engine) needs to invoke
;; commands with structured arguments through the command loop.
;;
;; Example usage:
;;
;;   (simulacrum-define-event-type my-event)
;;
;;   (keymap-global-set "<my-event>"
;;                      (simulacrum-command
;;                       (lambda (n) (message "Got %s" n))))
;;
;;   (simulacrum-generate-event 'my-event 42)
;;
;; When the command loop handles the generated event, it will execute
;; the command and print "Got 42".

;;; Code:

(require 'map)
(require 'repeat)

(defvar simulacrum--event-types (make-hash-table)
  "Defined event types.")

(defmacro simulacrum-define-event-type (type)
  "Define new input event TYPE."
  `(setf (map-elt simulacrum--event-types ',type) t))

(defun simulacrum-generate-event (type &rest data)
  "Generate synthetic input event TYPE with optional DATA.

TYPE is an event type defined with `simulacrum-define-event-type'.  The
event is handled by the usual keybinding mechanism.  For example:

  (simulacrum-define-event-type my-event-type)

  (keymap-global-set \"<my-event-type>\"
                     (simulacrum-command
                      (lambda (number)
                        (message \"Number emitted: %s\" number))))

Then evaluating

  (simulacrum-generate-event \\='my-event-type 54)

will output the message \"Number emitted: 54\".

The command is executed when the event is handled by the command
loop, not immediately."
  (unless (map-elt simulacrum--event-types type)
    (error "Event type `%S' not defined"
           type))
  (setq unread-command-events
        (append unread-command-events
                ;; (TYPE BEG END . DATA)
                ;; When BEG or END is nil, Emacs uses `posn-at-point'.
                ;; `describe-key' indirectly expects this form,
                ;; through calling `event-start' and `event-end'.
                ;; [2026-05-04 Mon]
                (list (append (list type nil nil)
                              data)))))

(defvar simulacrum--last-event nil)

(defun simulacrum--execute-command (function)
  "Call FUNCTION with the data arguments of the current event.
On `repeat', reuse the previous event's arguments."
  (let ((arguments (nthcdr 3 (if (repeat-is-really-this-command)
                                 simulacrum--last-event
                               last-command-event))))
    (apply function arguments)
    (unless (repeat-is-really-this-command)
      (setq last-repeatable-command this-command)
      (setq simulacrum--last-event last-command-event))))

(defun simulacrum-command (function)
  "Create a command from FUNCTION.

FUNCTION should take the same amount of arguments that is passed to
`simulacrum-generate-event'.  The created command can then be bound in a
keymap."
  ;; TODO: Store this in a hash for when we eventually want to hack
  ;; describe-key.  Remember to make the hash not hold the key from
  ;; the garbage collector.  We are going to want to add-advice
  ;; :filter-return to help--analyze-key to modify the returned value
  ;; whenever the computed definition is part of our hash.
  (lambda ()
    (interactive)
    (simulacrum--execute-command function)))

(provide 'simulacrum)
;;; simulacrum.el ends here
