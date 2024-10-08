(in-package :webdriver-client-test)

(defparameter +test-pages-filepath+ (asdf:system-relative-pathname :cl-webdriver-client-test "t/testpages.tar.gz"))

(defun download-test-pages ()
  (format t "Downloading test pages...~%")
  (uiop:run-program (list "curl" "-L" "https://github.com/copyleft/cl-webdriver-client/files/6430883/testpages.tar.gz"
                          "--output"
                          (princ-to-string +test-pages-filepath+))))

(defun uncompress-test-pages ()
  (format t "Uncompressing test pages...~%")
  (uiop:run-program
   (format nil "tar xzf ~a -C ~a"
           +test-pages-filepath+
           (asdf:system-relative-pathname :cl-webdriver-client-test "t/"))))

(defun test-file-url (name)
  (format nil "file://~a" (asdf:system-relative-pathname :cl-webdriver-client-test (format nil "t/web/~a" name))))

(defparameter *test-capabilities*
  (webdriver:make-capabilities
   :always-match `((platform-name . ,(webdriver::detect-platform-name)))
   :first-match (list `((browser-name . "chrome")
                        ,(webdriver:chrome-capabilities
                          :args #("--headless")))
                      `((browser-name . "firefox")
                        ,(webdriver:firefox-capabilities
                          :args #("--headless")))))
  "Capabilities used for test sessions")

(defmacro with-test-session (&body body)
  `(with-session *test-capabilities*
     ,@body))

(unless (probe-file (asdf:system-relative-pathname :cl-webdriver-client-test (format nil "t/web/")))
  (unless (probe-file +test-pages-filepath+)
    (download-test-pages))
  (uncompress-test-pages))

(plan nil)

;; This tests were taken from https://github.com/SeleniumHQ/selenium/blob/trunk/py/test/selenium/webdriver/common/

(subtest "Basic test"
  (with-test-session ()
    (setf (url) (test-file-url "xhtmlTest.html"))
    (ok (find-element "[name='someForm']"))))

;; Visibility tests

(subtest "Should allow the user to tell if an element is displayed or not"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (ok (element-displayed (find-element "displayed" :by :id)))
    (ok (not (element-displayed (find-element "none" :by :id))))
    (ok (not (element-displayed (find-element "suppressedParagraph" :by :id))))
    (ok (not (element-displayed (find-element "hidden" :by :id))))
    ))

(subtest "Visibility should take into account parent visibility"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (let ((child-div (find-element "hiddenchild" :by :id))
          (hidden-link (find-element "hiddenlink" :by :id)))
      (ok (not (element-displayed child-div)))
      (ok (not (element-displayed hidden-link)))
      )))

;; Typing

(subtest "Should fire key press events"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (let ((key-reporter (find-element "keyReporter" :by :id)))
      (element-send-keys key-reporter "a")
      (let ((result (find-element "result" :by :id)))
        (ok (search "press:" (element-text result) :test 'string=))))))


(subtest "Writable text input should clear"
  (with-test-session ()
    (setf (url) (test-file-url "readOnlyPage.html"))
    (let ((element (find-element "writableTextInput" :by :id)))
      (element-clear element)
      (ok (string= (element-attribute element "value") "")))))

(subtest "Text input should not clear when disabled"
  (with-test-session ()
    (setf (url) (test-file-url "readOnlyPage.html"))
    (let ((element (find-element "textInputnotenabled" :by :id)))
      ;; assert element is enabled here
      (is-error (element-clear element) 'error))))

;; Click

(subtest "Can click on a link that overflows and follows it"
  (with-test-session ()
    (setf (url) (test-file-url "clicks.html"))
    (element-click (find-element "overflowLink" :by :id))
    (sleep 2)
    (ok (string= (page-title) "XHTML Test Page"))))

;; Form handling

(subtest "Should click on submit input elements"
  (with-test-session ()
    (setf (url) (test-file-url "formPage.html"))
    (element-click (find-element "submitButton" :by :id))
    (sleep 3)
    (ok (string= (page-title) "We Arrive Here"))))


(subtest "Find elements test"
  (with-test-session ()
    (setf (url) (test-file-url "formPage.html"))
    ;; find-elements does not error
    (ok (null (find-elements "foo")))
    ;; find-element errors
    (is-error (find-element "foo") 'webdriver:no-such-element-error)
    (ok (find-element "body"))
    ))

(subtest "element-text"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (is (element-text (find-element "Change" :by :partial-link-text)) "Change the page title!")))

(subtest "element-rect"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (let ((rect (element-rect (find-element "Change" :by :partial-link-text))))
      (ok (assoc :x rect))
      (ok (assoc :y rect)))))

(subtest "element-tagname"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (is (element-tagname (find-element "[name=changeable]")) "input")))

(subtest "element-attribute"
  (with-test-session ()
    (setf (url) (test-file-url "formPage.html"))
    (let ((input (find-element "[name=id-name1]")))
      (element-clear input)
      (element-send-keys input "cl-cl-webdriver-client")
      (is (element-attribute input "value") "cl-cl-webdriver-client"))))

(subtest "active-element"
  (with-test-session ()
    (setf (url) (test-file-url "formPage.html"))
    (let ((input (find-element "[name=id-name1]")))
      (element-send-keys input "foo")
      (ok (element-id (active-element)))
      (is (element-attribute (active-element) "name") "id-name1"))))

(subtest "cookie"
  (with-test-session ()
    (setf (url) "https://www.google.com?hl=en")
    (ok (null (setf (cookie) (make-cookie "foo" "bar"))))
    (is (get-cookie (cookie) "foo") "bar")))

;; alerts

(subtest "accept alert manually"
  (with-test-session ()
    (setf (url) (test-file-url "alerts.html"))
    (element-click (find-element "alert" :by :id))
    (sleep 2)
    (accept-alert)
    (is (page-title) "Testing Alerts")))

;; actions

(subtest "actions: basics"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (perform-actions `((:none (:pause 5)))))
  )

(subtest "actions: move pointer"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (perform-actions `((:pointer
                        (:pointer-move 22 33)
                        (:pause 2000)
                        (:pointer-move 23 54))
                       ))
    ))

(subtest "actions: touch test"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (perform-actions `((:touch
                        (:pointer-move 22 33)
                        (:pause 2000)
                        (:pointer-move 23 54))
                       ))
    )
  )

(subtest "actions: mouse test"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (ok (null (perform-actions `((:mouse
                                  (:pointer-move 22 33)
                                  (:pause 2000)
                                  (:pointer-move 23 54))
                                 ))))
    )
  )

(subtest "actions: pen test"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (ok (null (perform-actions `((:pen
                                  (:pointer-move 22 33)
                                  (:pause 2000)
                                  (:pointer-move 23 54))
                                 ))))
    )
  )

(subtest "actions: pointer up/down"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (ok (null (perform-actions `((:mouse
                                  (:pointer-move 22 33)
                                  (:pause 2000)
                                  (:pointer-down 0)
                                  (:pointer-up 0)
                                  (:pointer-move 23 54))
                                 ))))
    )
  )

(subtest "actions: keys"
  (with-test-session ()
    (setf (url) (test-file-url "javascriptPage.html"))
    (ok (null (perform-actions `((:key
                                  (:pause 1000)
                                  (:key-down ,(key :shift))
                                  (:key-down "a"))))))
    ))

(subtest "take-screenshot"
  (with-test-session ()
    (with-open-file (stream "/tmp/test.html" :direction :output :if-exists :supersede)
      (format stream "<img src='data:image/png;base64,~a'>" (screenshot))))
  (ok (probe-file #p"/tmp/test.html")))

(subtest "execute-script"
  (with-test-session ()
    (is (execute-script "return arguments[0] + arguments[1];" '(2 3)) 5)
    (is (execute-script "return 42" nil) 42)))

(subtest "special-keys"
  (with-test-session ()
    (setf (url) (test-file-url "formPage.html"))
    (let ((input (find-element "[name=id-name1]")))
      (element-clear input)
      (element-send-keys input "client")
      (element-send-keys input (key :home))
      (element-send-keys input "cl-webdriver-")
      (is (element-attribute input "value") "cl-webdriver-client"))))

(subtest "refresh"
  (with-test-session ()
    (setf (url) (test-file-url "formPage.html"))
    (element-send-keys (find-element "[name=id-name1]") "cl-webdriver-client")
    (refresh)
    (is (element-text (find-element "[name=id-name1]")) "")))

(finalize)
