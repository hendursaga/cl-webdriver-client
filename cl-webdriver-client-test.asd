(defsystem cl-webdriver-client-test
  :author ("TatriX <tatrics@gmail.com>" "Mariano Montone <marianomontone@gmail.com>")
  :license "MIT"
  :depends-on (:cl-webdriver-client :prove)
  :defsystem-depends-on (:prove-asdf)
  :components
  ((module "t"
           :components ((:file "package")
			(:test-file "tests")
			;; Disabled old tests.
			;; Old tests are unreliable because they test on changing online Google pages.
			;;(:test-file "selenium")
                        ;;(:test-file "utils")
			)))
  :perform (test-op :after (op c)
                    (funcall (intern #.(string :run) :prove) c)))
