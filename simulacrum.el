;;; simulacrum.el --- Inject custom event types into the event stream  -*- lexical-binding: t; -*-

;; Copyright (C) 2025, 2026  Erik Präntare

;; Author: Erik Präntare
;; Version: 1.1.0
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
                ;; (TYPE BEG END (DATA))
                ;; When BEG or END is nil, Emacs uses `posn-at-point'.
                ;; `describe-key' indirectly expects this form,
                ;; through calling `event-start' and `event-end'.
                ;; [2026-05-04 Mon]

                ;; We also let DATA be wrapped in a list, otherwise
                ;; Emacs would interpret (TYPE nil nil nil) as a Lucid
                ;; event type (see lucid_event_type_list_p in
                ;; keyboard.c).  (TYPE nil nil (nil)) is correctly
                ;; seen as non-Lucid.
                (list (list type nil nil (list data))))))

(defun simulacrum--event-data (event)
  "Return the data associated to simulacrum-generated EVENT."
  (car (nth 3 event)))

(defvar simulacrum--last-event nil
  "Last simulacrum event executed.")

(defun simulacrum--execute-command (function)
  "Call FUNCTION with the data arguments of the current event.
On `repeat', reuse the previous event's arguments."
  ;; Main reason for this wrapper is to be able to set
  ;; `last-repeatable-command'.  I should consider somehow advising
  ;; repeat to override last-repeatable-command at that point.
  ;; `num-nonmacro-input-events' could be useda as an identifier for
  ;; the command.
  (let ((arguments (simulacrum--event-data
                    (if (repeat-is-really-this-command)
                        simulacrum--last-event
                      last-command-event))))
    (unless (or (repeat-is-really-this-command)
                (eq last-event-frame 'macro))
      (setq last-event-device "simulacrum"))
    (apply function arguments)
    (unless (repeat-is-really-this-command)
      (setq last-repeatable-command this-command)
      (setq simulacrum--last-event last-command-event))))

(defvar simulacrum--command-underlying-function
  (make-hash-table :weakness 'key)
  "Hash-table mapping live simulacrum commands to the corresponding function.")

(defun simulacrum-command (function)
  "Create a command from FUNCTION.

FUNCTION should take the same amount of arguments that is passed to
`simulacrum-generate-event'.  The created command can then be bound in a
keymap."
  (let ((command (lambda ()
                   (interactive)
                   (simulacrum--execute-command function))))
    (setf (map-elt simulacrum--command-underlying-function command) function)
    command))

(defun simulacrum--resolve-command (maybe-command)
  "Return the underlying function of MAYBE-COMMAND a simulacrum command.
If it is not a simulacrum command, return nil."
  (map-elt simulacrum--command-underlying-function maybe-command))

(define-advice help--analyze-key (:around (f key untranslated &optional buffer) simulacrum--resolve-command)
  "Replace returned simulacrum commands with the underlying function."
  (pcase-let* ((`(,brief-desc ,defn ,event ,mouse-msg) (funcall f key untranslated buffer)))
    (when-let* ((function (simulacrum--resolve-command defn)))
      (setq defn function)
      (setq brief-desc (format "%s runs the command %s" (help-key-description key untranslated) defn)))
    (list brief-desc defn event mouse-msg)))

(define-advice repeat-message (:filter-args (arguments) simulacrum--resolve-command)
  "Replace simulacrum commands in ARGS with their underlying function."
  (pcase-let* ((`(,format . ,arguments) arguments))
    (cons format (seq-map (lambda (argument)
                            (or (simulacrum--resolve-command argument) argument))
                          arguments))))

(define-advice device-class (:before-until (_frame name) simulacrum--resolve-device-class)
  (and (string-equal name "simulacrum") 'simulacrum))

(provide 'simulacrum)
;;; simulacrum.el ends here
