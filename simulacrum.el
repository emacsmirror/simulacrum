;;; simulacrum.el --- Inject arbitrary forms into the event stream  -*- lexical-binding: t; -*-

;; Copyright (C) 2025, 2026  Erik Präntare

;; Author: Erik Präntare <erik@adjoint-modality2>
;; Keywords: convenience
;; Created: 19 Aug 2025

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU Affero General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU Affero General Public
;; License along with this program.  If not, see
;; <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(defvar simulacrum-this-form nil
  "The form currently evaluated by simulacrum.

This variable may be changed by the evaluated form.  Whatever gets
put in this variable will be in `simulacrum-last-form' during the
form next evaluated.")

(defvar simulacrum-last-form nil
  "The form last evaluated by simulacrum.

This will be whatever `simulacrum-this-form' was at the end of the
previously evaluated form.")

(defun simulacrum--evaluate-form (form)
  "Evaluate FORM.

Before FORM is evaluated, `simulacrum-this-form' is set to FORM.
After FORM has been evaluated, `simulacrum-last-form' is set to
`simulacrum-this-form'."
  (interactive (list (cdr last-input-event)))
  (setq simulacrum-this-form form)
  (eval form)
  (setq simulacrum-last-form simulacrum-this-form))

(defun simulacrum-generate-event (type &optional data)
  "Generate synthetic input event TYPE with optional DATA.

This event can be handled by the usual methods of setting key bindings.
For example, with

  (keymap-global-set \"<my-event-type>\"
                     (lambda (number)
                       (interactive (list (cdr last-input-event)))
                       (message \"Number emitted: %s\" number)))

evaluating

  (simulacrum-generate-event 'my-event-type 54)

will output the message \"Number emitted: 54\".

As with all other keybindings, the command is executed at the point that
event is handled by the command loop.  This means that it is not
executed immediately.  This allows for multiple things

- Guaranteed execution ordering without blocking.
- Tracked by macros.
- Commands executed this way will interact with undo-borders in a more
  predictable way."
  (setq unread-command-events
        (append unread-command-events
                (list (cons type data)))))

;;; TODO
;; - Patch describe-key to handle user-defined event types.
;; - Patch repeat.el as well.

(provide 'simulacrum)
;;; simulacrum.el ends here
