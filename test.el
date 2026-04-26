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

(ert-deftest simulacrum-generated-event-triggers-command ()
  (let ((simulacrum--event-types (make-hash-table))
        (unread-command-events nil)
        (overriding-local-map (make-sparse-keymap))
        (result nil))
    (simulacrum-define-event-type test-event)
    (keymap-set overriding-local-map "<test-event>"
                (lambda ()
                  (interactive)
                  (setq result 'triggered)))
    (simulacrum-generate-event 'test-event)
    (execute-kbd-macro (seq-into unread-command-events 'vector))
    (should (eq result 'triggered))))

(ert-deftest simulacrum-generated-event-carries-data-payload ()
  (let ((simulacrum--event-types (make-hash-table))
        (unread-command-events nil)
        (overriding-local-map (make-sparse-keymap))
        (result nil))
    (simulacrum-define-event-type test-event)
    (keymap-set overriding-local-map "<test-event>"
                (lambda (data)
                  (interactive (list (cadr last-input-event)))
                  (setq result data)))
    (simulacrum-generate-event 'test-event 42)
    (execute-kbd-macro (seq-into unread-command-events 'vector))
    (should (equal result 42))))

(ert-deftest simulacrum-generating-undefined-event-signals-error ()
  (let ((simulacrum--event-types (make-hash-table))
        (unread-command-events nil))
    (should-error (simulacrum-generate-event 'undefined-event))
    (should (null unread-command-events))))
