(in-package :cl-selenium)

(defclass session ()
  ((id :initarg :id
       :initform (error "Must supply an id")
       :reader session-id))
  (:documentation "A Selenium Webdriver session.

The server should maintain one browser per session. Commands sent to a session will be directed to the corresponding browser."))

(defvar *session* nil "The current Selenium WebDriver session.")

(defun make-session (&key
                       (browser-name :chrome) ; TODO: autodetect?
                       browser-version
                       platform-name
                       platform-version
                       accept-ssl-certs
                       additional-capabilities)
  "Creates a new WebDriver session with the endpoint node. If the creation fails, a session not created error is returned.

See: https://www.w3.org/TR/webdriver1/#new-session .
See: https://www.w3.org/TR/webdriver1/#capabilities ."
  (let ((response (http-post "/session"
                             `(:session-id nil
                               :desired-capabilities ((browser-name . ,browser-name)
                                                      (browser-version . ,browser-version)
                                                      (platform-name . ,platform-name)
                                                      (platform-version . ,platform-version)
                                                      (accept-ssl-certs . ,accept-ssl-certs)
                                                      ,@additional-capabilities)))))
    ;; TODO: find/write json -> clos
    (make-instance 'session
                   :id (assoc-value response :session-id))))

(defun delete-session (session)
  "Delete the WebDriver SESSION."
  (http-delete-check (session-path session "")))

(defun use-session (session)
  "Make SESSION the current session."
  (setf *session* session))

(defmacro with-session ((&rest capabilities) &body body)
  "Execute BODY inside a Selenium session."
  (with-gensyms (session)
    `(let (,session)
       (unwind-protect
            (progn
              (setf ,session (make-session ,@capabilities))
              (let ((*session* ,session))
                ,@body))
         (when ,session
           (delete-session ,session))))))

(defun start-interactive-session (&rest capabilities)
  "Start an interactive session. Use this to interact with Selenium driver from a REPL."
  (when *session*
    (delete-session *session*))
  (setf *session* (apply #'make-session  capabilities)))

(defun stop-interactive-session ()
  "Stop an interactive session."
  (when *session*
    (delete-session *session*)
    (setf *session* nil)))

(defun session-path (session fmt &rest args)
  (format nil "/session/~a~a" (session-id session) (apply #'format nil fmt args)))
