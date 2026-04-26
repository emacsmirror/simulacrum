;;; test.el --- Tests for simulacrum.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Erik Präntare

;; Author: Erik Präntare <erik@adjoint-modality2>
;; Keywords: convenience
;; Created: 26 Apr 2026

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU Affero General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public
;; License along with this program.  If not, see
;; <http://www.gnu.org/licenses/>.


(require 'ert)
(require 'simulacrum)

(defmacro simulacrum-test (&rest body)
  "Evaluate BODY in a fresh simulacrum environment."
  (declare (indent 0))
  `(let ((simulacrum--event-types (make-hash-table))
         (simulacrum--last-event nil)
         (unread-command-events nil)
         (overriding-local-map (make-sparse-keymap)))
     ,@body))

(ert-deftest simulacrum-generated-event-triggers-command ()
  (simulacrum-test
   (let ((result nil))
     (simulacrum-define-event-type test-event)
     (keymap-set overriding-local-map "<test-event>"
                 (simulacrum-command
                  (lambda ()
                    (setq result 'triggered))))
     (simulacrum-generate-event 'test-event)
     (execute-kbd-macro (seq-into unread-command-events 'vector))
     (should (eq result 'triggered)))))

(ert-deftest simulacrum-generated-event-carries-data-payload ()
  (simulacrum-test
   (let ((result nil))
     (simulacrum-define-event-type test-event)
     (keymap-set overriding-local-map "<test-event>"
                 (simulacrum-command
                  (lambda (data)
                    (setq result data))))
     (simulacrum-generate-event 'test-event 42)
     (execute-kbd-macro (seq-into unread-command-events 'vector))
     (should (equal result 42)))))

(ert-deftest simulacrum-command-passes-multiple-arguments ()
  (simulacrum-test
   (let ((result nil))
     (simulacrum-define-event-type test-event)
     (keymap-set overriding-local-map "<test-event>"
                 (simulacrum-command
                  (lambda (a b c)
                    (setq result (list a b c)))))
     (simulacrum-generate-event 'test-event 1 2 3)
     (execute-kbd-macro (seq-into unread-command-events 'vector))
     (should (equal result '(1 2 3))))))

(ert-deftest simulacrum-command-repeats-with-saved-arguments ()
  (simulacrum-test
   (let ((total 0))
     (simulacrum-define-event-type test-event)
     (keymap-set overriding-local-map "<test-event>"
                 (simulacrum-command
                  (lambda (n)
                    (setq total (+ total n)))))
     (simulacrum-generate-event 'test-event 10)
     (let ((events (seq-into unread-command-events 'vector)))
       (setq unread-command-events nil)
       (execute-kbd-macro events))
     (should (= total 10))
     ;; If repeat-on-final-keystroke is not nil, repeat will try to
     ;; handle an event with data, which its cannot.
     (let ((repeat-on-final-keystroke nil))
       (repeat 1))
     (should (= total 20)))))

(ert-deftest simulacrum-generating-undefined-event-signals-error ()
  (simulacrum-test
   (should-error (simulacrum-generate-event 'undefined-event))
   (should (null unread-command-events))))
